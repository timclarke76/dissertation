#include <numeric>
#include <ranges>
#include <thread>

#include <config/args.h>
#include <config/settings.h>
#include <os/channel.h>
#include <os/shm.h>

#include <queue.h>
#include <thread/bridge.h>
#include <thread/fusion.h>
#include <thread/inference.h>
#include <thread/telemetry.h>

using namespace std::chrono_literals;

/// \brief Structure to hold configuration for each data stream.
struct StreamConfig
{
  /// The queue configuration for the data stream.
  const Settings::EventQueueConfig& queue;

  /// The stream ID for the data stream.
  const size_t stream_id;

  /// The policy for handling the data stream.
  const Policy& policy;

  /// The simulated inference time for the data stream.
  const std::chrono::duration<double> inference_time;
};

/// \brief Creates a bridge thread and an inference thread for a given shared
/// memory name, queue capacity, and backpressure policy.
///
/// \param stream_name The name of the stream to be used for shared memory and
/// telemetry.
/// \param stream_id The stream ID associated with the bridge thread.
/// \param queue_capacity The maximum number of frames that can be held in the
/// queue.
/// \param inference_sender A SyncSender<ShmBuffer::Frame> used to send
/// processed frames to the fusion thread.
/// \param policy The backpressure policy to apply when the queue is full.
/// \param inference_time The simulated time taken to process each frame in the
/// inference thread.
/// \param inference_window The number of frames to process in each inference
/// window.
/// \param frame_shape The shape of the frames being processed, suitable for
/// tensor.
/// \param item_size_bytes The size of each frame item in bytes (e.g., 1 byte
/// for uint8_t, 4 bytes for float).
///
/// \returns A pair of std::jthread objects representing the bridge and
/// inference threads, respectively.
std::pair<std::jthread, std::jthread>
spawn_bridge_and_inference_threads(const std::string& stream_name,
  const size_t stream_id,
  const size_t queue_capacity,
  Sender<ShmBuffer::Frame> inference_sender,
  const Policy& policy,
  const std::chrono::duration<double>& inference_time,
  const size_t inference_window,
  const std::vector<int64_t>& frame_shape,
  const size_t item_size_bytes)
{
  auto queue = std::make_shared<Queue<ShmBuffer::Frame>>(queue_capacity);
  auto bridge = spawn_bridge_thread(stream_name, stream_id, queue, policy);
  auto inference = spawn_inference_thread(stream_name,
    queue,
    inference_sender,
    inference_time,
    inference_window,
    frame_shape,
    item_size_bytes);

  return { std::move(bridge), std::move(inference) };
}

int
main(const int argc, const char* const* argv)
{
  const Settings settings(Args(argc, argv));

  // clang-format off
  const std::array<StreamConfig, 3> configs =
  {{
      {
          settings.get_rgb_queue_config(),
          ShmBuffer::RGB_STREAM_ID,
          settings.get_rgb_policy(),
          33ms
      },
      {
          settings.get_accel_queue_config(),
          ShmBuffer::ACCEL_STREAM_ID,
          settings.get_accel_policy(),
          500us
      },
      {
          settings.get_gyro_queue_config(),
          ShmBuffer::GYRO_STREAM_ID,
          settings.get_gyro_policy(),
          400us
      }
  }};
  // clang-format on

  size_t min_fps = std::numeric_limits<size_t>::max();

  for (const auto& cfg : configs) {
    min_fps = std::min(min_fps, cfg.queue.fps);
  }

  auto [inference_sender, fusion_receiver] =
    make_channel<ShmBuffer::Frame>(configs.size());
  std::vector<std::jthread> handles;

  for (const auto& cfg : configs) {
    auto [bridge, inference] =
      spawn_bridge_and_inference_threads(cfg.queue.name.c_str(),
        cfg.stream_id,
        cfg.queue.capacity_frames,
        inference_sender,
        cfg.policy,
        cfg.inference_time,
        size_t(cfg.queue.fps / min_fps),
        cfg.queue.frame_shape,
        cfg.queue.item_size_bytes);

    handles.push_back(std::move(bridge));
    handles.push_back(std::move(inference));
  }

  // clang-format off
  auto names_view = configs | std::views::transform([](const auto& cfg)
    { return cfg.queue.name; });
  // clang-format on

  handles.push_back(spawn_fusion_thread(std::move(fusion_receiver),
    std::vector<std::string>(names_view.begin(), names_view.end())));

  for (auto& handle : handles)
    handle.join();
}
