#include <format>
#include <vector>

#include <os/allocator.h>
#include <os/os.h>

#include "telemetry.h"

void
TelemetryWriter::Epoch::reset()
{
  for (size_t i = 0; i < NUM_LATENCY_MEASURES; ++i) {
    latency_nanos[i].reset();
  }

  allocated_bytes = 0;
  allocation_count = 0;
  freed_bytes = 0;
}

TelemetryWriter::Csv::Csv(const std::string_view& filename)
  : stream_(filename.data())
  , writer_(stream_)
{
  std::vector<std::string> header;

  for (auto label :
    { "unbounded", "idiomatic", "data", "inference", "fusion", "total" }) {
    header.push_back(std::format("{}_p50", label));
    header.push_back(std::format("{}_p99", label));
    header.push_back(std::format("{}_p99_9", label));
    header.push_back(std::format("{}_max", label));
  }

  header.push_back("allocated_bytes");
  header.push_back("allocation_count");
  header.push_back("freed_bytes");

  writer_.write_row(header);
  stream_.flush();
}

void
TelemetryWriter::Csv::write_epoch(const Epoch& epoch)
{
  std::vector<std::string> row;

  for (size_t i = 0; i < Epoch::NUM_LATENCY_MEASURES; ++i) {
    const auto p50 =
      static_cast<uint64_t>(epoch.latency_nanos[i].value_at_percentile(50.0));
    row.push_back(std::to_string(p50));

    const auto p99 =
      static_cast<uint64_t>(epoch.latency_nanos[i].value_at_percentile(99.0));
    row.push_back(std::to_string(p99));

    const auto p99_9 =
      static_cast<uint64_t>(epoch.latency_nanos[i].value_at_percentile(99.9));
    row.push_back(std::to_string(p99_9));

    row.push_back(std::to_string(epoch.latency_nanos[i].max()));
  }

  row.push_back(std::to_string(epoch.allocated_bytes));
  row.push_back(std::to_string(epoch.allocation_count));
  row.push_back(std::to_string(epoch.freed_bytes));

  writer_.write_row(row);
  stream_.flush();
}

void
TelemetryWriter::record(uint64_t ts[Epoch::NUM_LATENCY_MEASURES])
{
  if (std::chrono::steady_clock::now() - last_swap_ > SWAP_INTERVAL) {
    swap_buffers();
  }

  for (size_t idx = 0; idx < (Epoch::NUM_LATENCY_MEASURES - 1); idx++) {
    const auto nanos = saturating_sub(ts[idx + 1], ts[idx]);
    current_epoch_.latency_nanos[idx].record(std::max<uint64_t>(1, nanos));
  }

  const auto total_nanos =
    saturating_sub(ts[Epoch::TOTAL], ts[Epoch::UNBOUNDED_QUEUE_WAIT]);
  current_epoch_.latency_nanos[Epoch::NUM_LATENCY_MEASURES - 1].record(
    std::max<uint64_t>(1, total_nanos));
}

void
TelemetryWriter::swap_buffers()
{
  auto next_epoch_opt = receiver_.try_receive();

  if (next_epoch_opt.has_value()) {
    last_swap_ = std::chrono::steady_clock::now();
    sender_.send(std::move(current_epoch_));
    current_epoch_ = std::move(next_epoch_opt.value());
  }
}

std::jthread
spawn_telemetry_thread(const std::string_view& stream_name,
  Sender<TelemetryWriter::Epoch> sender,
  Receiver<TelemetryWriter::Epoch> receiver)
{
  // The `TelemetryEpoch` is used to record measurements, and is what is
  // communicated between the inference thread and the telemetry thread. Three
  // epochs are created:
  // * One will be used by the inference thread to record measurements.
  // * One will be used by the telemetry thread to process the completed
  //   measurements.
  // * One will be sitting in the channel, ready to be read in even if the
  //   telemetry thread is blocked while writing to the CSV file.
  for (size_t idx = 0; idx < 3; idx++) {
    auto epoch = TelemetryWriter::Epoch{};
    sender.send(std::move(epoch));
  }

  auto thread = std::jthread{
    [stream_name, sender, receiver = std::move(receiver)]() mutable {
      uint64_t last_allocated_bytes = 0;
      uint64_t last_allocation_count = 0;
      uint64_t last_freed_bytes = 0;

      // Telemtry is written to a CSV file for later analysis.
      TelemetryWriter::Csv csv(std::format("telemetry_{}.csv", stream_name));

      for (;;) {
        auto epoch = receiver.receive();

        // If the terminate flag is set, we break out of the loop and exit the
        // telemetry thread gracefully.
        if (epoch.terminated) {
          break;
        }

        // Now the inference thread is no longer updating the completed epoch,
        // we can save it.

        const auto currently_allocated_bytes =
          telemetry::allocated_bytes.load(std::memory_order_relaxed);
        epoch.allocated_bytes =
          saturating_sub(currently_allocated_bytes, last_allocated_bytes);
        last_allocated_bytes = currently_allocated_bytes;

        const auto currently_allocation_count =
          telemetry::allocation_count.load(std::memory_order_relaxed);
        epoch.allocation_count =
          saturating_sub(currently_allocation_count, last_allocation_count);
        last_allocation_count = currently_allocation_count;

        const auto currently_freed_bytes =
          telemetry::freed_bytes.load(std::memory_order_relaxed);
        epoch.freed_bytes =
          saturating_sub(currently_freed_bytes, last_freed_bytes);
        last_freed_bytes = currently_freed_bytes;

        csv.write_epoch(epoch);
        epoch.reset();
        sender.send(std::move(epoch));
      }
    }
  };

  pthread_setname_np(thread.native_handle(),
    std::format("telemetry{}", stream_name).substr(0, 15).c_str());

  return thread;
}
