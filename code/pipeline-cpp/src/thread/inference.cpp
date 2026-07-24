#include <cstring>
#include <numeric>

#include <os/os.h>
#include <os/time.h>

#include "inference.h"

std::jthread
spawn_inference_thread(const std::string& stream_name,
  std::shared_ptr<Queue<ShmBuffer::Frame>> queue,
  Sender<ShmBuffer::Frame> sender,
  const std::chrono::duration<double>& time,
  const size_t window_frames,
  const std::vector<int64_t>& frame_shape,
  const size_t item_size_bytes)
{
  // clang-format off
  auto thread = std::jthread([stream_name, sender, queue, time, window_frames,
    frame_shape, item_size_bytes]() mutable {
    // clang-format on
    const size_t window_size_items = std::accumulate(
      frame_shape.begin(), frame_shape.end(), 1LL, std::multiplies<int64_t>());
    const size_t window_size_bytes = window_size_items * item_size_bytes;
    const size_t frame_size_bytes = window_size_bytes / window_frames;

    std::vector<uint8_t> tensor_data(window_size_bytes, 0);
    char* tensor_ptr = reinterpret_cast<char*>(tensor_data.data());

    size_t samples_collected = 0;

    for (;;) {
      std::unique_lock<std::mutex> transaction_lock(queue->mutex);
      auto item = queue->pop();
      auto lapped_frames = queue->lapped_frames;
      auto dropped_frames = queue->dropped_frames;
      transaction_lock.unlock();

      if (item.has_value()) {
        item->lapped_frames = lapped_frames;
        item->dropped_frames = dropped_frames;

        if (item->seq_num == UINT64_MAX) {
          // The generator stream has ended, so we send the final
          // frame to the fusion thread and exit the loop.
          sender.send(std::move(item.value()));
          break;
        }

        const auto offset = samples_collected * frame_size_bytes;
        std::memcpy((tensor_ptr + offset), item->payload_ptr, frame_size_bytes);

        samples_collected++;

        if (samples_collected >= window_frames) {
          item->timestamps[ShmBuffer::PIPELINE_IN_TS] = current_time_nanos();
          std::this_thread::sleep_for(time); // Simulate inference
          item->timestamps[ShmBuffer::PIPELINE_OUT_TS] = current_time_nanos();

          try {
            sender.send(std::move(item.value()));
          } catch (const std::exception& e) {
            throw std::runtime_error(std::format(
              "Failed to send frame to output queue: {}", e.what()));
          }

          samples_collected = 0;
        }
      } else {
        spin_loop();
      }
    }
  });

  pthread_setname_np(thread.native_handle(),
    std::format("inference_{}", stream_name).substr(0, 15).c_str());

  return thread;
}
