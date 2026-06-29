use std::{
    sync::{
        atomic::Ordering,
        mpsc::{Receiver, SyncSender, sync_channel},
    },
    thread,
    time::{Duration, Instant},
};

use anyhow::{Context, Result};
use hdrhistogram::Histogram;

use crate::allocator::{ALLOCATED_BYTES, ALLOCATION_COUNT, FREED_BYTES};

/// A CSV file writer for telemetry data.
struct CsvFile {
    writer: csv::Writer<std::fs::File>,
}

impl CsvFile {
    /// Creates a new `CsvFile` writer for the specified file path. The writer
    /// is initialised with a header row containing the names of the latency
    /// percentiles for each stage of the inference pipeline, as well as the
    /// total latency.
    /// #Args
    /// * `file_path` - The path to the CSV file to be created.
    /// #Returns
    /// A `Result` containing the newly created `CsvFile`, or an error if the
    /// file could not be created or the header row could not be written.
    fn try_new<S: AsRef<str>>(file_path: S) -> Result<Self> {
        let mut writer = csv::Writer::from_path(file_path.as_ref())
            .with_context(|| {
                format!(
                    "Failed to create CSV writer for telemetry file '{}'",
                    file_path.as_ref()
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
    /// #Args
    /// * `epoch` - A reference to the `TelemetryEpoch` containing the latency
    ///   measurements to be written.
    /// #Returns
    /// A `Result` indicating whether the record was successfully written, or an
    /// error if the operation failed.
    fn write_record(&mut self, epoch: &TelemetryEpoch) -> Result<()> {
        let mut record = Vec::new();

        for histogram in epoch.latency_nanos.iter() {
            let p50 = histogram.value_at_quantile(0.5) as f64;
            let p99 = histogram.value_at_quantile(0.99) as f64;
            let p99_9 = histogram.value_at_quantile(0.999) as f64;
            let max = histogram.max();
            record.push(format!("{:.3}", p50));
            record.push(format!("{:.3}", p99));
            record.push(format!("{:.3}", p99_9));
            record.push(format!("{:.3}", max));
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

/// A telemetry epoch that contains six HdrHistogram instances for recording
/// latency measurements in nanoseconds. Each histogram tracks latency for a
/// specific stage of the inference pipeline, as well as the total latency.
pub struct TelemetryEpoch {
    latency_nanos: [Histogram<u64>; 6],
    allocated_bytes: usize,
    allocation_count: usize,
    freed_bytes: usize,
}

impl TelemetryEpoch {
    #[allow(dead_code)]
    pub const UNBOUNDED_QUEUE_WAIT: usize = 0;
    #[allow(dead_code)]
    pub const IDIOMATIC_QUEUE_WAIT: usize = 1;
    #[allow(dead_code)]
    pub const DATA_PREPARATION: usize = 2;
    #[allow(dead_code)]
    pub const INFERENCE: usize = 3;
    #[allow(dead_code)]
    pub const FUSION: usize = 4;
    #[allow(dead_code)]
    pub const TOTAL: usize = 5;

    /// Creates a new `TelemetryEpoch` with six HdrHistogram instances for
    /// recording latency measurements in nanoseconds. Each histogram is
    /// initialised to track values from 1 nanosecond to 60 seconds with 3
    /// significant figures of precision.
    /// #Returns
    /// A `Result` containing the newly created `TelemetryEpoch`, or an error if
    /// any of the histograms could not be initialised.
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
    /// #Returns
    /// A `Result` containing the newly created `Histogram<u64>`, or an error if
    /// the histogram could not be initialised.
    fn create_histogram() -> Result<Histogram<u64>> {
        Histogram::<u64>::new_with_bounds(1, 60_000_000_000, 3)
            .context("Failed to create HdrHistogram")
    }
}

/// A telemetry writer that records latency measurements into an epoch buffer.
/// Used by the inference thread to publish the results to the telemetry thread
/// for processing, and to receive a fresh buffer for the next epoch.
pub struct TelemetryWriter {
    /// The currently active telemetry epoch for recording latency measurements.
    current_epoch: TelemetryEpoch,

    /// The sender channel for publishing the current epoch to the telemetry
    /// thread for processing.
    sender: SyncSender<TelemetryEpoch>,

    /// The receiver channel for receiving a fresh epoch from the telemetry
    /// thread.
    receiver: Receiver<TelemetryEpoch>,

    /// The timestamp of the last buffer swap, used to determine when to next
    /// swap the buffers.
    last_swap: Instant,
}

impl TelemetryWriter {
    /// The interval at which the active epoch buffer is swapped with a fresh
    /// buffer received from the telemetry thread.
    const SWAP_INTERVAL: Duration = Duration::from_secs(1);

    /// Creates a new `TelemetryWriter` with the specified sender and receiver
    /// channels for double-buffered histogram processing.
    /// #Args
    /// * `sender` - The sender channel for publishing the populated epoch to
    ///   the telemetry thread for processing.
    /// * `receiver` - The receiver channel for receiving a fresh epoch buffer
    ///   from the telemetry thread.
    /// #Returns
    /// A `Result` containing the newly created `TelemetryWriter`, or an error
    /// if the histogram buffer could not be initialised
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
    /// #Args
    /// * `ts` - An array of six timestamps in nanoseconds, representing the
    ///   start and end times of each stage of the inference pipeline, as well
    ///   as the total latency.
    /// #Returns
    /// A `Result` indicating whether the latency measurements were successfully
    /// recorded, or an error if the operation failed.
    pub fn record(&mut self, ts: [u64; 6]) -> Result<()> {
        if self.last_swap.elapsed() >= Self::SWAP_INTERVAL {
            self.swap_buffers();
        }

        for i in 0..=4 {
            let nanos = ts[i + 1].saturating_sub(ts[i]);
            self.current_epoch.latency_nanos[i]
                .record(nanos)
                .context("Failed to record latency")?;
        }

        let total_nanos = ts[5].saturating_sub(ts[0]);
        self.current_epoch.latency_nanos[5]
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
/// #Args
/// * `stream_name` - The name of the stream to be used for telemetry and thread
///   identification.
/// #Returns
/// A `Result` containing the newly created `TelemetryWriter`, or an error if
/// the thread could not be spawned.
pub fn spawn_telemetry_thread<S: AsRef<str>>(
    stream_name: S,
) -> Result<TelemetryWriter> {
    let t_stream_name = stream_name.as_ref().to_string();

    // Create a pair of channels for double-buffered histogram processing. The
    // inference thread will send the populated epoch to the
    // telemetry thread for processing, and the telemetry thread will send a
    // fresh epoch to the inference thread for recording the next set of
    // measurements.
    let (inference_sender, telemetry_receiver) =
        sync_channel::<TelemetryEpoch>(3);
    let (telemetry_sender, inference_receiver) =
        sync_channel::<TelemetryEpoch>(3);

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
        telemetry_sender
            .send(epoch)
            .with_context(|| format!("Failed to send telemetry epoch {i}"))?;
    }

    let mut last_allocated_bytes = 0;
    let mut last_allocation_count = 0;
    let mut last_freed = 0;

    // Telemtry is written to a CSV file for later analysis.
    let csv_file_path = format!("telemetry_{}.csv", t_stream_name);
    let mut csv_file = CsvFile::try_new(&csv_file_path).with_context(|| {
        format!(
            "Failed to create CSV file for telemetry file '{}'",
            csv_file_path
        )
    })?;

    thread::Builder::new()
        .name(format!("telemetry_{}", t_stream_name))
        .spawn(move || {
            while let Ok(mut epoch) = telemetry_receiver.recv() {
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

                csv_file
                    .write_record(&epoch)
                    .expect("Failed to write telemetry record to CSV");

                epoch.reset();
                telemetry_sender
                    .send(epoch)
                    .expect("Failed to send clean telemetry epoch");
            }
        })
        .with_context(|| {
            let stream_name = stream_name.as_ref().to_string();
            format!("Failed to spawn telemetry thread for '{stream_name}'")
        })?;

    TelemetryWriter::try_new(inference_sender, inference_receiver)
}
