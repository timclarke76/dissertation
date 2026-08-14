#include <cstring>
#include <numeric>

#include <inference/inference_engine.h>
#include <os/os.h>
#include <os/shm.h>
#include <os/time.h>

#include "inference.h"

std::jthread
spawn_inference_thread(const std::string& stream_name,
  std::shared_ptr<Queue<ShmBuffer::Frame>> queue,
  Sender<ShmBuffer::Frame> sender,
  const std::string& model_path,
  const size_t window_frames,
  const std::vector<int64_t>& frame_shape,
  const size_t item_size_bytes)
{
  // clang-format off
  auto thread = std::jthread([stream_name, sender, queue, model_path,
    window_frames, frame_shape, item_size_bytes]() mutable {
    // clang-format on

    pthread_setname_np(pthread_self(),
      std::format("inference_{}", stream_name).substr(0, 15).c_str());

    const size_t window_size_items = static_cast<size_t>(std::accumulate(
      frame_shape.begin(), frame_shape.end(), 1LL, std::multiplies<int64_t>()));
    const size_t frame_size_items = window_size_items / window_frames;

    std::vector<float> tensor_data(window_size_items, 0.0f);
    InferenceEngine engine(model_path, frame_shape, tensor_data.data());

    size_t samples_collected = 0;

    for (;;) {
      std::unique_lock<std::mutex> transaction_lock(queue->get_mutex());
      auto item = queue->pop();
      const auto t_pipeline_in = current_time_nanos();
      auto lapped_frames = queue->get_lapped_frames();
      auto dropped_frames = queue->get_dropped_frames();
      transaction_lock.unlock();

      if (item.has_value()) {
        item->lapped_frames = lapped_frames;
        item->dropped_frames = dropped_frames;

        if (item->seq_num == ShmBuffer::Header::POISON_PILL) {
          // The generator stream has ended, so we send the final
          // frame to the fusion thread and exit the loop.
          sender.send(std::move(item.value()));
          break;
        }

        const size_t item_offset = samples_collected * frame_size_items;

        if (item_size_bytes == 1) {
          const uint8_t* raw_src =
            reinterpret_cast<const uint8_t*>(item->payload_ptr);
          for (size_t i = 0; i < frame_size_items; ++i) {
            tensor_data[item_offset + i] = static_cast<float>(raw_src[i]);
          }
        } else {
          const size_t frame_size_bytes = frame_size_items * sizeof(float);
          std::memcpy(tensor_data.data() + item_offset, 
            item->payload_ptr, 
            frame_size_bytes);
        }

        samples_collected++;

        if (samples_collected >= window_frames) {
          item->timestamps[ShmBuffer::PIPELINE_IN_TS] = t_pipeline_in;

          const auto& out = engine.run();
          std::copy(out.begin(), out.end(), std::begin(item->inference_result));

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

  return thread;
}
