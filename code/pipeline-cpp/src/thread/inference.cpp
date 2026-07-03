#include <iostream>

#include <os/os.h>
#include <os/time.h>

#include "inference.h"

std::jthread
spawn_inference_thread(const std::string& stream_name,
  Queue<ShmBuffer::Frame>& queue,
  Sender<ShmBuffer::Frame>& sender,
  const std::chrono::duration<double>& inference_time)
{
  auto thread = std::jthread([stream_name, &sender, &queue, inference_time]() {
    const auto start_time = std::chrono::steady_clock::now();

    for (;;) {
      std::unique_lock<std::mutex> transaction_lock(queue.mutex);
      auto item = queue.pop();
      transaction_lock.unlock();

      if (item.has_value()) {
        item->timestamps[ShmBuffer::PIPELINE_IN_TS] = current_time_nanos();
        std::this_thread::sleep_for(inference_time); // Simulate inference
        item->timestamps[ShmBuffer::PIPELINE_OUT_TS] = current_time_nanos();

        try {
          sender.send(std::move(item.value()));
        } catch (const std::exception& e) {
          throw std::runtime_error(
            std::format("Failed to send frame to output queue: {}", e.what()));
        }
      } else {
        spin_loop();
      }

      if (std::chrono::steady_clock::now() - start_time >
          std::chrono::seconds(10)) {
        std::cout << "Benchmark complete. Exiting.\n";
        return;
      }
    }
  });

  pthread_setname_np(thread.native_handle(),
    std::format("inference_{}", stream_name).substr(0, 15).c_str());

  return thread;
}
