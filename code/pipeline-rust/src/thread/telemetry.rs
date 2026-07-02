use std::{
    sync::{
        atomic::Ordering,
        mpsc::{Receiver, SyncSender},
    },
    thread::{self, JoinHandle},
    time::{Duration, Instant},
};

use anyhow::{Context, Result};
use hdrhistogram::Histogram;

use crate::allocator::{ALLOCATED_BYTES, ALLOCATION_COUNT, FREED_BYTES};

/// A telemetry epoch that contains six `HdrHistogram` instances for recording
/// latency measurements in nanoseconds. Each histogram tracks latency for a
/// specific stage of the inference pipeline, as well as the total latency.
pub struct TelemetryEpoch {
    /// The histograms for recording latency measurements in nanoseconds for
    /// each stage of the inference pipeline, as well as the total latency.
    latency_nanos: [Histogram<u64>; 6],

    /// The total number of bytes allocated during the epoch.
    allocated_bytes: usize,

    /// The total number of allocations made during the epoch.
    allocation_count: usize,

    /// The total number of bytes freed during the epoch.
    freed_bytes: usize,
}

impl TelemetryEpoch {
    /// The index of the histogram for unbounded queue wait latency.
    pub const UNBOUNDED_QUEUE_WAIT: usize = 0;

    /// The index of the histogram for idiomatic queue wait latency.
    pub const IDIOMATIC_QUEUE_WAIT: usize = 1;

    /// The index of the histogram for data preparation latency.
    pub const DATA_PREPARATION: usize = 2;

    /// The index of the histogram for inference latency.
    pub const INFERENCE: usize = 3;

    /// The index of the histogram for fusion latency.
    pub const FUSION: usize = 4;

    /// The index of the histogram for total latency.
    pub const TOTAL: usize = 5;

    /// The number of latency measures tracked in an epoch.
    pub const NUM_LATENCY_MEASURES: usize = Self::TOTAL + 1;

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

        let data_preparation = Self::create_histogram().context(
            "Failed to create HdrHistogram for data preparation latency",
        )?;

        let inference = Self::create_histogram()
            .context("Failed to create HdrHistogram for inference latency")?;

        let fusion = Self::create_histogram()
            .context("Failed to create HdrHistogram for fusion latency")?;

        let total = Self::create_histogram()
            .context("Failed to create HdrHistogram for total latency")?;

        Ok(Self {
            latency_nanos: [
                unbounded_queue_wait,
                idiomatic_queue_wait,
                data_preparation,
                inference,
                fusion,
                total,
            ],
            allocated_bytes: 0,
            allocation_count: 0,
            freed_bytes: 0,
        })
    }

    /// Resets the histograms and allocation statistics for the epoch.
    fn reset(&mut self) {
        for histogram in self.latency_nanos.iter_mut() {
            histogram.reset();
        }

        self.allocated_bytes = 0;
        self.allocation_count = 0;
        self.freed_bytes = 0;
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
    /// The CSV writer for writing telemetry records to a file.
    writer: csv::Writer<std::fs::File>,
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
    fn try_new<S: AsRef<str>>(filename: S) -> Result<Self> {
        let mut writer = csv::Writer::from_path(filename.as_ref())
            .with_context(|| {
                format!(
                    "Failed to create CSV writer for telemetry file '{}'",
                    filename.as_ref()
                )
            })?;

        let mut record = Vec::new();

        for label in [
            "unbounded",
            "idiomatic",
            "data",
            "inference",
            "fusion",
            "total",
        ] {
            record.push(format!("{}_p50", label));
            record.push(format!("{}_p99", label));
            record.push(format!("{}_p99_9", label));
            record.push(format!("{}_max", label));
        }

        record.push("allocated_bytes".to_string());
        record.push("allocation_count".to_string());
        record.push("freed_bytes".to_string());

        writer
            .write_record(&record)
            .expect("Failed to write telemetry record to CSV");

        Ok(Self { writer })
    }

    /// Writes a telemetry record to the CSV file.
    ///
    /// * `epoch` - The telemetry epoch containing the latency measurements to
    /// be written.
    ///
    /// Returns a `Result` indicating whether the record was successfully
    /// written, or an error if the operation failed.
    fn write_record(&mut self, epoch: &TelemetryEpoch) -> Result<()> {
        let mut record = Vec::new();

        for histogram in epoch.latency_nanos.iter() {
            record.push(histogram.value_at_quantile(0.5).to_string());
            record.push(histogram.value_at_quantile(0.99).to_string());
            record.push(histogram.value_at_quantile(0.999).to_string());
            record.push(histogram.max().to_string());
        }

        record.push(epoch.allocated_bytes.to_string());
        record.push(epoch.allocation_count.to_string());
        record.push(epoch.freed_bytes.to_string());

        self.writer
            .write_record(record)
            .context("Failed to write telemetry record to CSV")?;
        self.writer.flush().context("Failed to flush CSV writer")?;

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
    ///
    /// Returns a `Result` indicating whether the latency measurements were
    /// successfully recorded, or an error if the operation failed.
    pub fn record(&mut self, ts: [u64; 6]) -> Result<()> {
        if self.last_swap.elapsed() >= Self::SWAP_INTERVAL {
            self.swap_buffers();
        }

        for idx in 0..(TelemetryEpoch::NUM_LATENCY_MEASURES - 1) {
            let nanos = ts[idx + 1].saturating_sub(ts[idx]);
            self.current_epoch.latency_nanos[idx]
                .record(nanos)
                .context("Failed to record latency")?;
        }

        let total_nanos = ts[TelemetryEpoch::TOTAL]
            .saturating_sub(ts[TelemetryEpoch::UNBOUNDED_QUEUE_WAIT]);
        self.current_epoch.latency_nanos[TelemetryEpoch::TOTAL]
            .record(total_nanos)
            .context("Failed to record total latency")?;

        Ok(())
    }

    /// Swaps the active histogram buffer with the cleared buffer received from
    /// the background thread. The populated buffer is sent to the background
    /// thread for processing, and the timestamp of the last swap is updated.
    fn swap_buffers(&mut self) {
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
                .expect("Failed to send completed epoch to telemetry thread");
        }
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
pub fn spawn_telemetry_thread<S: AsRef<str>>(
    stream_name: S,
    sender: SyncSender<TelemetryEpoch>,
    receiver: Receiver<TelemetryEpoch>,
) -> Result<JoinHandle<()>> {
    let t_stream_name = stream_name.as_ref().to_string();

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

    // Telemtry is written to a CSV file for later analysis.
    let csv_filename = format!("telemetry_{}.csv", t_stream_name);
    let mut csv = Csv::try_new(&csv_filename).with_context(|| {
        format!(
            "Failed to create CSV file for telemetry file '{}'",
            csv_filename
        )
    })?;

    thread::Builder::new()
        .name(format!("telemetry_{}", t_stream_name))
        .spawn(move || {
            let mut last_allocated_bytes = 0;
            let mut last_allocation_count = 0;
            let mut last_freed = 0;

            while let Ok(mut epoch) = receiver.recv() {
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

                csv.write_record(&epoch)
                    .expect("Failed to write telemetry record to CSV");

                epoch.reset();
                sender
                    .send(epoch)
                    .expect("Failed to send clean telemetry epoch");
            }
        })
        .with_context(|| {
            let stream_name = stream_name.as_ref().to_string();
            format!("Failed to spawn telemetry thread for '{stream_name}'")
        })
}
