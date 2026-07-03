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
  /// \brief The queue configuration for the data stream.
  const Settings::QueueConfig& queue;

  /// \brief The stream ID for the data stream.
  const size_t stream_id;

  /// \brief The policy for handling the data stream.
  const Policy& policy;

  /// \brief The simulated inference time for the data stream.
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
///
/// \returns A pair of std::jthread objects representing the bridge and
/// inference threads, respectively.
std::pair<std::jthread, std::jthread>
spawn_bridge_and_inference_threads(const std::string& stream_name,
  const size_t stream_id,
  const size_t queue_capacity,
  Sender<ShmBuffer::Frame>& inference_sender,
  const Policy& policy,
  const std::chrono::duration<double>& inference_time)
{
  auto queue = std::make_shared<Queue<ShmBuffer::Frame>>(queue_capacity);
  auto bridge = spawn_bridge_thread(stream_name, stream_id, *queue, policy);
  auto inference = spawn_inference_thread(
    stream_name, *queue, inference_sender, inference_time);

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
          settings.rgb_queue_config,
          ShmBuffer::RGB_STREAM_ID,
          settings.rgb_policy,
          33ms
      },
      {
          settings.accel_queue_config,
          ShmBuffer::ACCEL_STREAM_ID,
          settings.accelerometer_policy,
          500us
      },
      {
          settings.gyro_queue_config,
          ShmBuffer::GYRO_STREAM_ID,
          settings.gyroscope_policy,
          400us
      }
  }};
  // clang-format on

  size_t channel_size = 0;

  for (const auto& cfg : configs)
    channel_size += cfg.queue.capacity_frames;

  auto [inference_sender, fusion_receiver] =
    make_channel<ShmBuffer::Frame>(channel_size);
  std::vector<std::jthread> handles;

  for (const auto& cfg : configs) {
    auto [bridge, inference] =
      spawn_bridge_and_inference_threads(cfg.queue.name.c_str(),
        cfg.stream_id,
        cfg.queue.capacity_frames,
        inference_sender,
        cfg.policy,
        cfg.inference_time);

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
