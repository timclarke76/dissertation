use std::{
    fs::File,
    io::{Read, Write},
    sync::{
        atomic::Ordering,
        mpsc::{Receiver, SyncSender},
    },
    thread::{self, JoinHandle},
    time::{Duration, Instant},
};

use anyhow::{Context, Result};
use hdrhistogram::Histogram;

use crate::os::{ALLOCATED_BYTES, ALLOCATION_COUNT, FREED_BYTES};

/// A telemetry epoch that contains six `HdrHistogram` instances for recording
/// latency measurements in nanoseconds. Each histogram tracks latency for a
/// specific stage of the inference pipeline, as well as the total latency.
pub struct TelemetryEpoch {
    /// The histograms for recording latency measurements in nanoseconds for
    /// each stage of the inference pipeline, as well as the total latency.
    latency_nanos: [Histogram<u64>; 6],

    /// The total number of frames lapped during the epoch.
    lapped_frames: u64,

    /// The total number of frames dropped during the epoch.
    dropped_frames: u64,

    /// The total number of bytes allocated during the epoch.
    allocated_bytes: usize,

    /// The total number of allocations made during the epoch.
    allocation_count: usize,

    /// The total number of bytes freed during the epoch.
    freed_bytes: usize,

    /// The total number of allocated RSS bytes during the epoch.
    pub rss_bytes: usize,

    /// The total number of allocated fordblks bytes during the epoch.
    pub fordblks_bytes: usize,

    /// A flag indicating whether the telemetry thread should terminate.
    terminated: bool,
}

impl TelemetryEpoch {
    /// The index of the histogram for unbounded queue wait latency.
    pub const UNBOUNDED_QUEUE_WAIT: usize = 0;

    /// The index of the histogram for idiomatic queue wait latency.
    #[allow(unused)]
    pub const IDIOMATIC_QUEUE_WAIT: usize = 1;

    /// The index of the histogram for inference latency.
    #[allow(unused)]
    pub const INFERENCE_EXEC: usize = 2;

    /// The index of the histogram for multi-producer single-consumer (MPSC)
    /// queue wait latency.
    #[allow(unused)]
    pub const MPSC_WAIT: usize = 3;

    /// The index of the histogram for fusion latency.
    #[allow(unused)]
    pub const FUSION_EXEC: usize = 4;

    /// The index of the histogram for total latency.
    pub const TOTAL_LATENCY: usize = 5;

    /// The number of latency measures tracked in an epoch.
    pub const NUM_LATENCY_MEASURES: usize = 6;

    /// Creates a new `TelemetryEpoch` with six HdrHistogram instances for
    /// recording latency measurements in nanoseconds. Each histogram is
    /// initialised to track values from 1 nanosecond to 60 seconds with 3
    /// significant figures of precision.
    ///
    /// Returns a `Result` containing the newly created `TelemetryEpoch`, or an
    /// error if any of the histograms could not be initialised.
    pub fn try_new() -> Result<Self> {
        let unbounded_queue_wait = Self::create_histogram().context(
            "Failed to create HdrHistogram for unbounded queue wait latency",
        )?;

        let idiomatic_queue_wait = Self::create_histogram().context(
            "Failed to create HdrHistogram for idiomatic queue wait latency",
        )?;

        let inference_exec = Self::create_histogram().context(
            "Failed to create HdrHistogram for inference exec latency",
        )?;

        let mpsc_wait = Self::create_histogram()
            .context("Failed to create HdrHistogram for MPSC wait latency")?;

        let fusion_exec = Self::create_histogram()
            .context("Failed to create HdrHistogram for fusion exec latency")?;

        let total_latency = Self::create_histogram()
            .context("Failed to create HdrHistogram for total latency")?;

        Ok(Self {
            latency_nanos: [
                unbounded_queue_wait,
                idiomatic_queue_wait,
                inference_exec,
                mpsc_wait,
                fusion_exec,
                total_latency,
            ],
            lapped_frames: 0,
            dropped_frames: 0,
            allocated_bytes: 0,
            allocation_count: 0,
            freed_bytes: 0,
            rss_bytes: 0,
            fordblks_bytes: 0,
            terminated: false,
        })
    }

    /// Resets the histograms and allocation statistics for the epoch.
    fn reset(&mut self) {
        for histogram in self.latency_nanos.iter_mut() {
            histogram.reset();
        }

        self.lapped_frames = 0;
        self.dropped_frames = 0;
        self.allocated_bytes = 0;
        self.allocation_count = 0;
        self.freed_bytes = 0;
        self.rss_bytes = 0;
        self.fordblks_bytes = 0;
    }

    /// Creates a new HdrHistogram instance for recording latency measurements
    /// in nanoseconds. The histogram is initialised to track values from 1
    /// nanosecond to 60 seconds with 3 significant figures of precision.
    ///
    /// Returns a `Result` containing the newly created `Histogram<u64>`, or an
    /// error if the histogram could not be initialised.
    fn create_histogram() -> Result<Histogram<u64>> {
        Histogram::<u64>::new_with_bounds(1, 60_000_000_000, 3)
            .context("Failed to create HdrHistogram")
    }
}

/// A CSV file writer for telemetry data.
struct Csv {
    file: File,
}

impl Csv {
    /// Creates a new `Csv` writer for the specified filename. The writer is
    /// initialised with a header row containing the names of the latency
    /// percentiles for each stage of the inference pipeline, as well as the
    /// total latency.
    ///
    /// * `filename` - The name of the CSV file to write to.
    ///
    /// Returns a `Result` containing the newly created `Csv`, or an error if
    /// the file could not be created or the header row could not be written.
    fn try_new(filename: impl Into<String>) -> Result<Self> {
        let filename = filename.into();
        let mut file = File::create(&filename).with_context(|| {
            format!("Failed to create CSV telemtry file '{}'", filename)
        })?;

        let header = b"unbounded_wait_p50,unbounded_wait_p99,unbounded_wait_p99_9,unbounded_wait_max,\
            idiomatic_wait_p50,idiomatic_wait_p99,idiomatic_wait_p99_9,idiomatic_wait_max,\
            inference_exec_p50,inference_exec_p99,inference_exec_p99_9,inference_exec_max,\
            mpsc_wait_p50,mpsc_wait_p99,mpsc_wait_p99_9,mpsc_wait_max,\
            fusion_exec_p50,fusion_exec_p99,fusion_exec_p99_9,fusion_exec_max,\
            total_latency_p50,total_latency_p99,total_latency_p99_9,total_latency_max,\
            lapped_frames,dropped_frames,allocated_bytes,allocation_count,\
            freed_bytes,rss_bytes,fordblks_bytes\n";

        file.write_all(header).expect("Failed to write CSV header");

        Ok(Self { file })
    }

    /// Writes a telemetry record to the CSV file.
    ///
    /// * `epoch` - The telemetry epoch containing the latency measurements to
    /// be written.
    ///
    /// Returns a `Result` indicating whether the record was successfully
    /// written, or an error if the operation failed.
    fn write_record(&mut self, epoch: &TelemetryEpoch) -> Result<()> {
        const BUFFER_SIZE: usize = 1024;

        let mut buf = [0u8; BUFFER_SIZE];
        let mut cursor = &mut buf[..];
        let mut itoa_buf = itoa::Buffer::new();

        let mut append = |val: u64| {
            let s = itoa_buf.format(val);
            cursor.write_all(s.as_bytes()).unwrap();
            cursor.write_all(b",").unwrap();
        };

        for histogram in epoch.latency_nanos.iter() {
            append(histogram.value_at_quantile(0.5));
            append(histogram.value_at_quantile(0.99));
            append(histogram.value_at_quantile(0.999));
            append(histogram.max());
        }

        append(epoch.lapped_frames);
        append(epoch.dropped_frames);
        append(epoch.allocated_bytes as u64);
        append(epoch.allocation_count as u64);
        append(epoch.freed_bytes as u64);
        append(epoch.rss_bytes as u64);
        append(epoch.fordblks_bytes as u64);

        // Replace final comma with newline.
        let written = BUFFER_SIZE - cursor.len();
        buf[written - 1] = b'\n';

        self.file
            .write_all(&buf[..written])
            .context("Failed to write telemetry record to CSV")?;

        Ok(())
    }
}

/// Records latency measurements into an epoch buffer. Used by the inference
/// thread to publish the results to the telemetry thread for processing, and to
/// receive a fresh buffer for the next epoch.
pub struct TelemetryWriter {
    /// The sender channel for publishing the current epoch to the telemetry
    /// thread for processing.
    sender: SyncSender<TelemetryEpoch>,

    /// The receiver channel for receiving a fresh epoch from the telemetry
    /// thread.
    receiver: Receiver<TelemetryEpoch>,

    /// The timestamp of the last buffer swap, used to determine when to next
    /// swap the buffers.
    last_swap: Instant,

    /// The number of frames lapped since the call to record, used to calculate
    /// the number of lapped frames for the current epoch.
    last_lapped_frames: u64,

    /// The number of frames dropped since the call to record, used to
    /// calculate the number of dropped frames for the current epoch.
    last_dropped_frames: u64,

    /// The currently active telemetry epoch for recording latency measurements.
    current_epoch: TelemetryEpoch,
}

impl TelemetryWriter {
    /// The interval at which the active epoch buffer is swapped with a fresh
    /// buffer received from the telemetry thread.
    const SWAP_INTERVAL: Duration = Duration::from_secs(1);

    /// Constructs a new `TelemetryWriter` with the specified sender and
    /// receiver channels for double-buffered histogram processing.
    ///
    /// * `sender` - The sender channel for publishing the populated epoch to
    ///   the telemetry thread for processing.
    /// * `receiver` - The receiver channel for receiving a fresh epoch buffer
    ///   from the telemetry thread.
    ///
    /// Returns a `Result` containing the newly created `TelemetryWriter`, or an
    /// error if the histogram buffer could not be initialised
    pub fn try_new(
        sender: SyncSender<TelemetryEpoch>,
        receiver: Receiver<TelemetryEpoch>,
    ) -> Result<Self> {
        let current_epoch = receiver
            .recv()
            .context("Failed to receive initial telemetry epoch")?;

        Ok(Self {
            current_epoch,
            sender,
            receiver,
            last_swap: Instant::now(),
            last_lapped_frames: 0,
            last_dropped_frames: 0,
        })
    }

    /// Records latency measurements into the currently active telemetry epoch.
    /// If at least one second has elapsed since the last buffer swap, the
    /// active buffer is swapped with a fresh buffer received from the telemetry
    /// thread.
    ///
    /// * `ts` - An array of six timestamps in nanoseconds, representing the
    ///   start and end times of each stage of the inference pipeline, as well
    ///   as the total latency.
    /// * `lapped_frames` - The total number of frames lapped.
    /// * `dropped_frames` - The total number of frames dropped.
    ///
    /// Returns a `Result` indicating whether the latency measurements were
    /// successfully recorded, or an error if the operation failed.
    pub fn record(
        &mut self,
        ts: [u64; 6],
        lapped_frames: u64,
        dropped_frames: u64,
    ) -> Result<()> {
        if self.last_swap.elapsed() >= Self::SWAP_INTERVAL {
            self.swap_buffers()?;
        }

        for idx in 0..(TelemetryEpoch::NUM_LATENCY_MEASURES - 1) {
            let nanos = ts[idx + 1].saturating_sub(ts[idx]).max(1);
            self.current_epoch.latency_nanos[idx]
                .record(nanos)
                .context("Failed to record latency")?;
        }

        let total_nanos = ts[TelemetryEpoch::TOTAL_LATENCY]
            .saturating_sub(ts[TelemetryEpoch::UNBOUNDED_QUEUE_WAIT]);
        self.current_epoch.latency_nanos[TelemetryEpoch::TOTAL_LATENCY]
            .record(total_nanos)
            .context("Failed to record total latency")?;

        let newly_lapped =
            lapped_frames.saturating_sub(self.last_lapped_frames);
        self.current_epoch.lapped_frames += newly_lapped;
        self.last_lapped_frames = lapped_frames;

        let newly_dropped =
            dropped_frames.saturating_sub(self.last_dropped_frames);
        self.current_epoch.dropped_frames += newly_dropped;
        self.last_dropped_frames = dropped_frames;

        Ok(())
    }

    /// Swaps the active histogram buffer with the cleared buffer received from
    /// the background thread. The populated buffer is sent to the background
    /// thread for processing, and the timestamp of the last swap is updated.
    fn swap_buffers(&mut self) -> Result<()> {
        // Try to receive the fresh epoch from the telemetry thread. If the
        // channel is empty, we skip the swap and continue recording into the
        // current epoch.
        if let Ok(mut epoch) = self.receiver.try_recv() {
            self.last_swap = Instant::now();

            // Using `std::mem::swap` to swap the populated epoch with the fresh
            // epoch, avoiding the need for cloning or moving the data.
            std::mem::swap(&mut self.current_epoch, &mut epoch);

            // Send the completed epoch to the telemetry thread for processing.
            self.sender
                .try_send(epoch)
                .expect("Failed to send completed epoch to telemetry thread")
        }

        Ok(())
    }

    /// Signals the telemetry thread to terminate by setting the `terminated`
    /// flag in the current epoch and sending it to the telemetry thread.
    pub fn terminate(&mut self) -> Result<()> {
        self.current_epoch.terminated = true;
        self.swap_buffers()
    }
}

/// Spawns a background thread for processing telemetry data from a
/// `TelemetryWriter`. The telemtry thread receives populated epoch buffers from
/// the `TelemetryWriter`, calculates latency percentiles, and saves the results
/// to a CSV file for later analysis.
///
/// * `stream_name` - The name of the stream to be used for telemetry and thread
///   identification.
/// * `sender` - The sender channel for publishing the current epoch to the
///   telemetry thread for processing.
/// * `receiver` - The receiver channel for receiving a fresh epoch buffer from
///   the telemetry thread.
///
/// Returns a `Result` containing the join handle for the spawned thread, or an
/// error if the thread could not be spawned.
pub fn spawn_telemetry_thread(
    stream_name: impl Into<String>,
    sender: SyncSender<TelemetryEpoch>,
    receiver: Receiver<TelemetryEpoch>,
) -> Result<JoinHandle<()>> {
    let stream_name = stream_name.into();

    // The `TelemetryEpoch` is used to record measurements, and is what is
    // communicated between the inference thread and the telemetry thread. Three
    // epochs are created:
    // * One will be used by the inference thread to record measurements.
    // * One will be used by the telemetry thread to process the completed
    //   measurements.
    // * One will be sitting in the channel, ready to be read in even if the
    //   telemetry thread is blocked while writing to the CSV file.
    for i in 0..=2 {
        let epoch = TelemetryEpoch::try_new()
            .with_context(|| format!("Failed to create telemetry epoch {i}"))?;
        sender
            .send(epoch)
            .with_context(|| format!("Failed to send telemetry epoch {i}"))?;
    }

    // Telemetry is written to a CSV file for later analysis.
    let csv_filename = format!("telemetry_{}.csv", stream_name);
    let mut csv = Csv::try_new(&csv_filename).with_context(|| {
        format!(
            "Failed to create CSV file for telemetry file '{}'",
            csv_filename
        )
    })?;

    thread::Builder::new()
        .name(format!("telemetry_{}", stream_name))
        .spawn(move || {
            let page_size =
                unsafe { libc::sysconf(libc::_SC_PAGESIZE) as usize };
            let mut last_allocated_bytes = 0;
            let mut last_allocation_count = 0;
            let mut last_freed = 0;

            while let Ok(mut epoch) = receiver.recv() {
                // If the `terminated` flag is set, we break out of the loop and
                // exit the telemetry thread gracefully.
                if epoch.terminated {
                    break;
                }

                // Now the inference thread is no longer updating the completed
                // epoch, we can save it.

                let current_allocated_bytes =
                    ALLOCATED_BYTES.load(Ordering::Relaxed);
                epoch.allocated_bytes = current_allocated_bytes
                    .saturating_sub(last_allocated_bytes);
                last_allocated_bytes = current_allocated_bytes;

                let current_allocation_count =
                    ALLOCATION_COUNT.load(Ordering::Relaxed);
                epoch.allocation_count = current_allocation_count
                    .saturating_sub(last_allocation_count);
                last_allocation_count = current_allocation_count;

                let current_freed_bytes = FREED_BYTES.load(Ordering::Relaxed);
                epoch.freed_bytes =
                    current_freed_bytes.saturating_sub(last_freed);
                last_freed = current_freed_bytes;

                let mut statm_file = std::fs::File::open("/proc/self/statm")
                    .expect("Failed to open /proc/self/statm");

                let mut sbuf = [0u8; 128];
                let n =
                    statm_file.read(&mut sbuf).expect("Failed to read statm");

                if n > 0 {
                    let mut start = 0;

                    // Ignore size.
                    while sbuf[start] != b' ' && start < n {
                        start += 1;
                    }
                    if start < n {
                        start += 1;
                    }

                    let mut end = start;
                    while sbuf[end] != b' ' && end < n {
                        end += 1;
                    }

                    let rss_str = std::str::from_utf8(&sbuf[start..end])
                        .expect("Invalid UTF-8 in statm");
                    let rss_pages: usize = rss_str.parse().expect(
                        "Failed to parse resident pages from /proc/self/statm",
                    );

                    epoch.rss_bytes = rss_pages * page_size;
                }

                epoch.fordblks_bytes =
                    unsafe { libc::mallinfo2().fordblks as usize };

                csv.write_record(&epoch)
                    .expect("Failed to write telemetry record to CSV");

                epoch.reset();
                sender
                    .send(epoch)
                    .expect("Failed to send clean telemetry epoch");
            }
        })
        .with_context(|| {
            format!("Failed to spawn telemetry thread for '{stream_name}'")
        })
}
