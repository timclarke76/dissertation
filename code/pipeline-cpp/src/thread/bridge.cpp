#include "bridge.h"

#include <format>
#include <memory>
#include <numeric>

#include <os/os.h>

// clang-format off
template<class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template<class... Ts> overloaded(Ts...) -> overloaded<Ts...>;
// clang-format on

std::jthread
spawn_bridge_thread(const std::string& shm_name,
  const size_t stream_id,
  Queue<ShmBuffer::Frame>& queue,
  const Policy& policy)
{
  auto thread = std::jthread([shm_name, stream_id, &queue, policy]() {
    ShmBuffer shm_buffer(shm_name, stream_id);
    uint64_t seq_num = 0;
    uint64_t decimation_counter = 0;
    ShmBuffer::Frame frame;

    for (;;) {
      seq_num++;

      try {
        frame = shm_buffer.next_frame();
      } catch (const std::exception& e) {
        throw std::runtime_error(
          "Failed to read next frame from shared memory");
      }

      frame.seq_num = seq_num;
      std::unique_lock<std::mutex> queue_lock(queue.mutex);

      if (std::holds_alternative<AdaptiveDecimation>(policy)) {
        // Dynamically downsamples the data stream (i.e. queueing only every nth
        // event) to reduce pressure on the consumer buffer while preserving the
        // temporal continuity of the data.

        // When using Adaptive Decimation, and the queue's length is above a
        // given threshold, only every nth frame is queued and the remained are
        // discarded _before_ attempting to push to the queue. N is calculated
        // based on how deep into the "danger zone" (the region between the
        // threshold and the queue's capacity) we are, and scaled between a
        // minimum and maximum ratio.

        const auto& adp = std::get<AdaptiveDecimation>(policy);

        if (queue.len() > adp.threshold) {
          // Determine how deep into the danger zone we are, and scale the
          // decimation ratio accordingly. `saturating_sub` avoids underflow and
          // wraparound.
          const auto zone_size =
            saturating_sub(queue.capacity(), adp.threshold);
          const auto depth = saturating_sub(queue.len(), adp.threshold);

          // Calculate a decimation ratio scaled between min_ratio and max_ratio
          // based on how deep into the danger zone that we are. The deeper we
          // are, the closer we get to max_ratio. If we are at the threshold, we
          // use min_ratio.
          auto ratio = adp.max_ratio;

          if (zone_size > 0) {
            const auto numerator = depth * (adp.max_ratio - adp.min_ratio);
            ratio = adp.min_ratio + (numerator / zone_size);
          }

          decimation_counter++;

          if (decimation_counter % ratio != 0) {
            queue.dropped_frames++;
            continue; // drop
          }
        } else {
          // reset
          decimation_counter = 0;
        }
      }

      // clang-format off
      if (!queue.push(frame)) {
        std::visit(
          overloaded{
            [&queue, &queue_lock, frame](const BoundedQueue&) mutable {
              // Blocks the producer until space is available in the consumer
              // buffer.
              queue_lock.unlock();

              for (;;) {
                spin_loop();
                queue_lock.lock();

                if (queue.push(frame)) {
                  break;
                }
              }
            },

            [&queue, &queue_lock, frame](const ExponentialBackoff& p) mutable {
              // Waits a short time before retrying to insert the data, with the
              // wait time multiplied with each retry.
              auto backoff_nanos = static_cast<double>(p.base_nanos);

              for (;;) {
                queue_lock.unlock();
                std::this_thread::sleep_for(std::chrono::nanoseconds(
                  static_cast<uint64_t>(backoff_nanos)));
                queue_lock.lock();

                if (queue.push(frame)) {
                  break;
                }

                backoff_nanos *= p.multiplier;

                if (backoff_nanos >= static_cast<double>(p.max_nanos)) {
                  queue.dropped_frames++;
                  break;
                }
              }
            },

            [&queue, frame](const DropOldest&) {
                // Drops the oldest data in the consumer buffer to make room for
                // new data.
                queue.overwrite_oldest(frame);
                queue.dropped_frames++;
            },

            [&queue](const DropNewest&) {
                // DropNewest drops incoming data when the buffer is full.
                queue.dropped_frames++;
            },

            [&queue](const AdaptiveDecimation&) {
                // If the Adaptive Decimation throttling is not enough to keep
                // the queue from filling up, we drop the incoming frame.
                queue.dropped_frames++;
            },

          }, policy);
      }
      // clang-format on
    }
  });

  pthread_setname_np(thread.native_handle(),
    std::format("bridge_{}", shm_name).substr(0, 15).c_str());

  return thread;
}
