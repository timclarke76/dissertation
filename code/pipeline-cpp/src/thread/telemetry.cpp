#include <charconv>
#include <cstring>
#include <fcntl.h>
#include <format>
#include <malloc.h>
#include <unistd.h>
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

  lapped_frames = 0;
  dropped_frames = 0;
  allocated_bytes = 0;
  allocation_count = 0;
  freed_bytes = 0;
  rss_bytes = 0;
  fordblks_bytes = 0;
}

TelemetryWriter::Csv::Csv(const std::string_view& filename)
{
  fd_ = open(filename.data(), O_CREAT | O_WRONLY | O_TRUNC, 0644);

  if (fd_ < 0) {
    throw std::runtime_error(std::format(
      "Failed to open CSV file '{}': {}", filename, std::strerror(errno)));
  }

  // clang-format off
  const char* header =
    "timestamp_ns,"
    "unbounded_wait_p50,unbounded_wait_p99,unbounded_wait_p99_9,unbounded_wait_max,"
    "idiomatic_wait_p50,idiomatic_wait_p99,idiomatic_wait_p99_9,idiomatic_wait_max,"
    "inference_exec_p50,inference_exec_p99,inference_exec_p99_9,inference_exec_max,"
    "mpsc_wait_p50,mpsc_wait_p99,mpsc_wait_p99_9,mpsc_wait_max,"
    "fusion_exec_p50,fusion_exec_p99,fusion_exec_p99_9,fusion_exec_max,"
    "total_latency_p50,total_latency_p99,total_latency_p99_9,total_latency_max,"
    "lapped_frames,dropped_frames,allocated_bytes,allocation_count,"
    "freed_bytes,rss_bytes,fordblks_bytes\n";
  // clang-format on

  if (write(fd_, header, std::strlen(header)) < 0) {
    throw std::runtime_error(
      std::format("Failed to write CSV header to '{}': {}",
        filename,
        std::strerror(errno)));
  }
}

TelemetryWriter::Csv::~Csv()
{
  if (fd_ >= 0) {
    close(fd_);
  }
}

void
TelemetryWriter::Csv::write_epoch(const Epoch& epoch,
  const uint64_t timestamp_ns)
{
  // Plenty of space for the CSV row, since the maximum number of characters for
  // a 64-bit integer is 20, and there are 31 fields, plus commas and a newline.
  char buf[1024];
  char* ptr = buf;
  char* end = buf + sizeof(buf);

  auto append = [&](uint64_t v) {
    auto res = std::to_chars(ptr, end, v);
    ptr = res.ptr;

    // This will always be true, but adding the check prevents the compiler from
    // complaining about writing past the end of the buffer.
    if (ptr < end) {
      *ptr++ = ',';
    }
  };

  append(timestamp_ns);

  for (size_t i = 0; i < Epoch::NUM_LATENCY_MEASURES; ++i) {
    append(
      static_cast<uint64_t>(epoch.latency_nanos[i].value_at_percentile(50.0)));
    append(
      static_cast<uint64_t>(epoch.latency_nanos[i].value_at_percentile(99.0)));
    append(
      static_cast<uint64_t>(epoch.latency_nanos[i].value_at_percentile(99.9)));
    append(epoch.latency_nanos[i].max());
  }

  append(epoch.lapped_frames);
  append(epoch.dropped_frames);
  append(epoch.allocated_bytes);
  append(epoch.allocation_count);
  append(epoch.freed_bytes);
  append(epoch.rss_bytes);
  append(epoch.fordblks_bytes);

  // Replace final comma with newline.
  *(ptr - 1) = '\n';

  if (write(fd_, buf, ptr - buf) < 0) {
    throw std::runtime_error(
      std::format("Failed to write CSV row: {}", std::strerror(errno)));
  }
}

void
TelemetryWriter::record(uint64_t ts[Epoch::NUM_LATENCY_MEASURES],
  const uint64_t lapped_frames,
  const uint64_t dropped_frames)
{
  if (is_terminated_)
    return;

  if (std::chrono::steady_clock::now() - last_swap_ > SWAP_INTERVAL) {
    swap_buffers();
  }

  for (size_t idx = 0; idx < (Epoch::NUM_LATENCY_MEASURES - 1); idx++) {
    const auto nanos = saturating_sub(ts[idx + 1], ts[idx]);
    current_epoch_->latency_nanos[idx].record(std::max<uint64_t>(1, nanos));
  }

  const auto total_nanos =
    saturating_sub(ts[Epoch::TOTAL_LATENCY], ts[Epoch::UNBOUNDED_QUEUE_WAIT]);
  current_epoch_->latency_nanos[Epoch::TOTAL_LATENCY].record(
    std::max<uint64_t>(1, total_nanos));

  const auto newly_lapped = saturating_sub(lapped_frames, last_lapped_frames_);
  current_epoch_->lapped_frames += newly_lapped;
  last_lapped_frames_ = lapped_frames;

  const auto newly_dropped =
    saturating_sub(dropped_frames, last_dropped_frames_);
  current_epoch_->dropped_frames += newly_dropped;
  last_dropped_frames_ = dropped_frames;
}

void
TelemetryWriter::swap_buffers()
{
  // Reset timer to guarantee one check per second.
  last_swap_ = std::chrono::steady_clock::now();

  auto next_epoch_opt = receiver_.try_receive();

  if (next_epoch_opt.has_value()) {
    sender_.send(std::move(current_epoch_));
    current_epoch_ = std::move(next_epoch_opt.value());
  }
}

std::jthread
spawn_telemetry_thread(const std::string_view& stream_name,
  Sender<std::unique_ptr<TelemetryWriter::Epoch>> sender,
  Receiver<std::unique_ptr<TelemetryWriter::Epoch>> receiver)
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
    sender.send(std::make_unique<TelemetryWriter::Epoch>());
  }

  auto thread = std::jthread{
    [stream_name, sender, receiver = std::move(receiver)]() mutable {
      pthread_setname_np(pthread_self(),
        std::format("telemetry_{}", stream_name).substr(0, 15).c_str());

      const long PAGE_SIZE = sysconf(_SC_PAGESIZE);
      uint64_t last_allocated_bytes = 0;
      uint64_t last_allocation_count = 0;
      uint64_t last_freed_bytes = 0;

      // Telemtry is written to a CSV file for later analysis.
      TelemetryWriter::Csv csv(std::format("telemetry_{}.csv", stream_name));

      for (;;) {
        auto epoch = receiver.receive();
        const uint64_t timestamp_ns =
          std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::system_clock::now().time_since_epoch())
            .count();

        // If the terminate flag is set, we break out of the loop and exit the
        // telemetry thread gracefully.
        if (epoch->terminated) {
          break;
        }

        // Now the inference thread is no longer updating the completed epoch,
        // we can save it.

        const auto currently_allocated_bytes =
          telemetry::allocated_bytes.load(std::memory_order_relaxed);
        epoch->allocated_bytes =
          saturating_sub(currently_allocated_bytes, last_allocated_bytes);
        last_allocated_bytes = currently_allocated_bytes;

        const auto currently_allocation_count =
          telemetry::allocation_count.load(std::memory_order_relaxed);
        epoch->allocation_count =
          saturating_sub(currently_allocation_count, last_allocation_count);
        last_allocation_count = currently_allocation_count;

        const auto currently_freed_bytes =
          telemetry::freed_bytes.load(std::memory_order_relaxed);
        epoch->freed_bytes =
          saturating_sub(currently_freed_bytes, last_freed_bytes);
        last_freed_bytes = currently_freed_bytes;

        const int statm_fd = open("/proc/self/statm", O_RDONLY);
        if (statm_fd < 0) {
          throw std::runtime_error("Failed to open /proc/self/statm");
        }

        char sbuf[128];
        ssize_t n = read(statm_fd, sbuf, sizeof(sbuf) - 1);
        close(statm_fd);

        if (n > 0) {
          char* p = sbuf;

          // Ignore size.
          while (p < sbuf + n && *p != ' ')
            p++;
          if (p < sbuf + n && *p == ' ')
            p++;

          long resident = 0;
          std::from_chars(p, sbuf + n, resident);
          epoch->rss_bytes = resident * PAGE_SIZE;
        }

        epoch->fordblks_bytes = mallinfo2().fordblks;

        csv.write_epoch(*epoch, timestamp_ns);
        epoch->reset();
        sender.send(std::move(epoch));
      }
    }
  };

  return thread;
}
