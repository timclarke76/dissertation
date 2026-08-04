#pragma once
#include <chrono>
#include <cstddef>
#include <iterator>
#include <memory>
#include <string_view>
#include <thread>

#include <blockingconcurrentqueue.h>
#include <histogram.h>

#include <os/channel.h>

/// \brief Records latency measurements into an epoch buffer.
///
/// Used by the inference thread to publish the results to the telemetry thread
/// for processing, and to receive a fresh buffer for the next epoch.
class TelemetryWriter
{
public:
  /// \brief A telemetry epoch that contains six HdrHistogram instances for
  /// recording latency measurements in nanoseconds.
  ///
  /// Each histogram tracks latency for a specific stage of the inference
  /// pipeline, as well as the total latency.
  class Epoch
  {
  public:
    /// The index of the histogram for unbounded queue wait latency.
    static constexpr size_t UNBOUNDED_QUEUE_WAIT = 0;

    /// The index of the histogram for idiomatic queue wait latency.
    static constexpr size_t IDIOMATIC_QUEUE_WAIT = 1;

    /// The index of the histogram for inference latency.
    static constexpr size_t INFERENCE_EXEC = 2;

    // The index of the histogram for multi-producer single-consumer (MPSC)
    // queue wait latency.
    static constexpr size_t MPSC_WAIT = 3;

    /// The index of the histogram for fusion latency.
    static constexpr size_t FUSION_EXEC = 4;

    /// The index of the histogram for total latency.
    static constexpr size_t TOTAL_LATENCY = 5;

    /// The number of latency measures tracked in an epoch.
    static constexpr size_t NUM_LATENCY_MEASURES = 6;

    /// \brief Constructs a new Epoch instance with default-initialized
    /// histograms and zeroed allocation statistics.
    Epoch() = default;

    /// \brief Destroys the Epoch instance, releasing any resources held by the
    /// histograms.
    ~Epoch() = default;

    /// \brief Move constructor for the Epoch class.
    Epoch(Epoch&&) noexcept = default;

    /// \brief Move assignment operator for the Epoch class.
    Epoch& operator=(Epoch&&) noexcept = default;

    // Delete copy constructor and copy assignment operator.
    Epoch(const Epoch&) = delete;
    Epoch& operator=(const Epoch&) = delete;

    /// \brief Resets the histograms and allocation statistics for the epoch.
    void reset();

    /// The histograms for recording latency measurements in nanoseconds for
    /// each stage of the inference pipeline, as well as the total latency.
    Histogram latency_nanos[NUM_LATENCY_MEASURES];

    /// The total number of frames lapped during the epoch.
    uint64_t lapped_frames = 0;

    /// The total number of frames dropped during the epoch.
    uint64_t dropped_frames = 0;

    /// The total number of bytes allocated during the epoch.
    size_t allocated_bytes = 0;

    /// The total number of allocations made during the epoch.
    size_t allocation_count = 0;

    /// The total number of bytes freed during the epoch.
    size_t freed_bytes = 0;

    /// The total number of allocated RSS bytes during the epoch.
    size_t rss_bytes = 0;

    /// The total number of allocated fordblks bytes during the epoch.
    size_t fordblks_bytes = 0;

    /// A flag indicating whether the telemetry thread should terminate.
    bool terminated = false;
  };

  /// \brief A CSV file writer for telemetry data.
  class Csv
  {
  public:
    /// \brief Creates a new Csv writer for the specified filename.
    ///
    /// The writer is initialised with a header row containing the names of the
    /// latency percentiles for each stage of the inference pipeline, as well as
    /// the total latency.
    ///
    /// \param filename The name of the CSV file to write to.
    Csv(const std::string_view& filename);

    ~Csv();

    /// \brief Writes a telemetry record to the CSV file.
    ///
    /// \param epoch The telemetry epoch containing the latency measurements to
    /// be written.
    /// \param timestamp_ns The timestamp in nanoseconds at which the telemetry
    /// epoch was received.
    void write_epoch(const Epoch& epoch, const uint64_t timestamp_ns);

  private:
    /// The file descriptor for the CSV file.
    int fd_ = -1;
  };

private:
  /// The interval at which the active epoch buffer is swapped with a fresh
  /// buffer received from the telemetry thread.
  static constexpr std::chrono::duration<double> SWAP_INTERVAL =
    std::chrono::seconds(1);

public:
  /// \brief Constructs a new TelemetryWriter instance with the specified sender
  /// and receiver channels for double-buffered histogram processing.
  ///
  /// \param sender The sender channel for publishing the current epoch to the
  /// telemetry thread for processing.
  /// \param receiver The receiver channel for receiving a fresh epoch from the
  /// telemetry thread.
  TelemetryWriter(Sender<std::unique_ptr<Epoch>> sender,
          Receiver<std::unique_ptr<Epoch>> receiver)
    : sender_(std::move(sender))
    , receiver_(std::move(receiver))
    , last_swap_(std::chrono::steady_clock::now())
    , current_epoch_(receiver_.receive())
  {
  }

  /// \brief Records latency measurements into the currently active telemetry
  /// epoch.
  ///
  /// If at least one second has elapsed since the last buffer swap, the active
  /// buffer is swapped with a fresh buffer received from the telemetry thread.
  ///
  /// \param ts An array of six timestamps in nanoseconds, representing the
  /// start and end times of each stage of the inference pipeline, as well as
  /// the total latency.
  /// \param lapped_frames The total number of frames lapped.
  /// \param dropped_frames The total number of frames dropped.
  void record(uint64_t ts[Epoch::NUM_LATENCY_MEASURES],
    const uint64_t lapped_frames,
    const uint64_t dropped_frames);

  /// \brief Signals the telemetry thread to terminate by setting the terminate
  /// flag in the current epoch and sending it to the telemetry thread. It needs
  /// to be guaranteed that the epoch is sent, regardless of whether the
  /// telemetry thread is blocked or not, to ensure that the telemetry thread
  /// can exit gracefully. Therefore swap_buffers() is not called here, and
  /// instead the termination epoch is sent directly.
  void terminate()
  {
    if (is_terminated_) return;

    is_terminated_ = true;
    current_epoch_->terminated = true;
    sender_.send(std::move(current_epoch_));
  }

private:
  /// \brief Swaps the active histogram buffer with the cleared buffer received
  /// from the background thread.
  ///
  /// The populated buffer is sent to the background thread for processing, and
  /// the timestamp of the last swap is updated.
  void swap_buffers();

  /// The sender channel for publishing the current epoch to the telemetry
  /// thread for processing.
  Sender<std::unique_ptr<Epoch>> sender_;

  /// The receiver channel for receiving a fresh epoch from the telemetry
  /// thread.
  Receiver<std::unique_ptr<Epoch>> receiver_;

  /// The timestamp of the last buffer swap, used to determine when to next swap
  /// the buffers.
  std::chrono::steady_clock::time_point last_swap_;

  /// The number of frames lapped since the call to record, used to calculate
  /// the number of lapped frames for the current epoch.
  uint64_t last_lapped_frames_ = 0;

  /// The number of frames dropped since the call to record, used to calculate
  /// the number of dropped frames for the current epoch.
  uint64_t last_dropped_frames_ = 0;

  /// The currently active telemetry epoch for recording latency measurements.
  std::unique_ptr<Epoch> current_epoch_;

  /// A flag indicating whether the telemetry thread has been signaled to
  /// terminate.
  bool is_terminated_ = false;
};

/// \brief Spawns a background thread for processing telemetry data from a
/// TelemetryWriter.
///
/// The telemtry thread receives populated epoch buffers from the
/// TelemetryWriter, calculates latency percentiles, and saves the results to a
/// CSV file for later analysis.
///
/// \param stream_name The name of the stream to be used for telemetry and
/// thread identification.
/// \param sender The sender channel for publishing the current epoch to the
/// telemetry thread for processing.
/// \param receiver The receiver channel for receiving a fresh epoch from the
/// telemetry thread.
/// \returns A std::jthread representing the spawned telemetry thread.
std::jthread
spawn_telemetry_thread(const std::string_view& stream_name,
  Sender<std::unique_ptr<TelemetryWriter::Epoch>> sender,
  Receiver<std::unique_ptr<TelemetryWriter::Epoch>> receiver);
