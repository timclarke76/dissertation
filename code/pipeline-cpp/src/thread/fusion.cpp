#include <os/os.h>
#include <os/time.h>
#include <thread/telemetry.h>

#include "fusion.h"

std::jthread
spawn_fusion_thread(Receiver<ShmBuffer::Frame> receiver,
  const std::vector<std::string>& stream_names)
{
  auto thread = std::jthread([stream_names,
                               receiver = std::move(receiver)]() mutable {
    auto telemetry_threads = std::vector<std::jthread>();
    auto telemetry_writers = std::vector<TelemetryWriter>();

    for (const auto& name : stream_names) {
      auto [telemetry_sender, inference_receiver] =
        make_channel<TelemetryWriter::Epoch>(3);
      auto [inference_sender, telemetry_receiver] =
        make_channel<TelemetryWriter::Epoch>(3);

      try {
        telemetry_threads.push_back(spawn_telemetry_thread(
          name, std::move(telemetry_sender), std::move(telemetry_receiver)));
      } catch (const std::exception& e) {
        throw std::runtime_error("Failed to spawn telemetry thread");
      }

      try {
        telemetry_writers.push_back(TelemetryWriter(
          std::move(inference_sender), std::move(inference_receiver)));
      } catch (const std::exception& e) {
        throw std::runtime_error("Failed to create telemetry writer");
      }
    }

    // Required to save the latest accelerometer and gyrometer timestamps for
    // fusion telemetry.
    uint64_t latest_accel_ts[ShmBuffer::NUM_TIMESTAMPS] = { 0 };
    uint64_t latest_accel_lapped_frames = 0;
    uint64_t latest_accel_dropped_frames = 0;
    uint64_t latest_gyro_ts[ShmBuffer::NUM_TIMESTAMPS] = { 0 };
    uint64_t latest_gyro_lapped_frames = 0;
    uint64_t latest_gyro_dropped_frames = 0;

    size_t eos_count = 0;

    for (;;) {
      auto frame = receiver.receive();

      if (frame.seq_num == UINT64_MAX) {
        // A generator stream has ended. Terminate the corresponding
        // telemetry writer and increment the end-of-stream count.
        // If all streams have ended, exit the loop.
        telemetry_writers[frame.stream_id].terminate();
        eos_count++;

        if (eos_count == ShmBuffer::NUM_STREAMS) {
          break;
        }

        // Wait for all streams to end before exiting the loop.
        // Don't process the EOS frame.
        continue;
      }

      switch (frame.stream_id) {
        case ShmBuffer::ACCEL_STREAM_ID:
          // Only the most recent accelerometer timestamps are needed for
          // fusion, so we store them here.
          std::copy(std::begin(frame.timestamps),
            std::end(frame.timestamps),
            std::begin(latest_accel_ts));
          latest_accel_lapped_frames = frame.lapped_frames;
          latest_accel_dropped_frames = frame.dropped_frames;
          break;

        case ShmBuffer::GYRO_STREAM_ID:
          // Only the most recent gyrometer timestamps are needed for fusion,
          // so we store them here.
          std::copy(std::begin(frame.timestamps),
            std::end(frame.timestamps),
            std::begin(latest_gyro_ts));
          latest_gyro_lapped_frames = frame.lapped_frames;
          latest_gyro_dropped_frames = frame.dropped_frames;
          break;

        case ShmBuffer::RGB_STREAM_ID:
          // Do not fuse or record telemetry until all streams
          // have provided at least one valid frame for ZoH.
          if (latest_accel_ts[ShmBuffer::GENERATED_TS] == 0 ||
              latest_gyro_ts[ShmBuffer::GENERATED_TS] == 0) {
            continue;
          }

          frame.timestamps[ShmBuffer::FUSION_IN_TS] = current_time_nanos();
          std::this_thread::sleep_for(std::chrono::milliseconds(5));
          frame.timestamps[ShmBuffer::FUSION_OUT_TS] = current_time_nanos();

          // Record the RGB telemetry.
          try {
            telemetry_writers[ShmBuffer::RGB_STREAM_ID].record(
              frame.timestamps, frame.lapped_frames, frame.dropped_frames);
          } catch (const std::exception& e) {
            throw std::runtime_error("Failed to record RGB telemetry");
          }

          // Copy the fusion timestamps and record the accelerometer
          // telemetry.
          latest_accel_ts[ShmBuffer::FUSION_IN_TS] =
            frame.timestamps[ShmBuffer::FUSION_IN_TS];
          latest_accel_ts[ShmBuffer::FUSION_OUT_TS] =
            frame.timestamps[ShmBuffer::FUSION_OUT_TS];

          try {
            telemetry_writers[ShmBuffer::ACCEL_STREAM_ID].record(
              latest_accel_ts,
              latest_accel_lapped_frames,
              latest_accel_dropped_frames);
          } catch (const std::exception& e) {
            throw std::runtime_error(
              "Failed to record accelerometer telemetry");
          }

          // Copy the fusion timestamps and record the gyrometer telemetry.
          latest_gyro_ts[ShmBuffer::FUSION_IN_TS] =
            frame.timestamps[ShmBuffer::FUSION_IN_TS];
          latest_gyro_ts[ShmBuffer::FUSION_OUT_TS] =
            frame.timestamps[ShmBuffer::FUSION_OUT_TS];

          try {
            telemetry_writers[ShmBuffer::GYRO_STREAM_ID].record(latest_gyro_ts,
              latest_gyro_lapped_frames,
              latest_gyro_dropped_frames);
          } catch (const std::exception& e) {
            throw std::runtime_error("Failed to record gyrometer telemetry");
          }

          break;

        default:
          throw std::runtime_error(
            "Unknown stream ID: " + std::to_string(frame.stream_id));
          break;
      }
    }

    for (auto& thread : telemetry_threads) {
      thread.join();
    }
  });

  pthread_setname_np(thread.native_handle(), "fusion");

  return thread;
}
