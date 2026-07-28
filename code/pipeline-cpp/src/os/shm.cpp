#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <format>
#include <iostream>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include <os/os.h>
#include <os/time.h>

#include "shm.h"

ShmBuffer::ShmBuffer(const std::string_view& name, const size_t stream_id)
  : stream_id_(stream_id)
{
  header_ = open_shm_file(name);

  if (header_->magic != Header::MAGIC) {
    throw std::runtime_error(std::format(
      "Memory corruption or invalid magic number in shared memory '{}'",
      name));
  }

  if (header_->version != Header::VERSION) {
    throw std::runtime_error(std::format(
      "Incompatible version in shared memory '{}': expected {}, got {}",
      name,
      Header::VERSION,
      header_->version));
  }

  data_ptr_ = reinterpret_cast<char*>(header_) + sizeof(Header);
  capacity_frames_ = header_->capacity_frames;
  frame_size_bytes_ = header_->frame_size_bytes;

  header_->pipeline_stage.store(
    ShmBuffer::Header::READY, std::memory_order_release);
}

ShmBuffer::Frame
ShmBuffer::next_frame()
{
  for (;;) {
    // The producer increments the sequence number after writing a frame, using
    // Release ordering to ensure all previous writes have been flushed. The
    // consumer uses Acquire ordering to ensure it sees the latest writes to the
    // frame data.
    const uint64_t seq_num = header_->seq_num.load(std::memory_order_acquire);

    if (seq_num > frame_idx_) {
      const auto t_bridged = current_time_nanos();
      uint64_t lapped_frames = 0;

      if (seq_num - frame_idx_ > header_->capacity_frames) {
        // The producer has lapped the consumer, which means that frames have
        // been overwritten before they could be read. Jump ahead to the oldest
        // surviving frame. For example, if the producer is at sequence 35 and
        // the capacity is 30, the oldest surviving frame is at sequence 6.

        lapped_frames = seq_num - frame_idx_;
        frame_idx_ = seq_num - capacity_frames_;
      }

      const auto circular_idx =
        static_cast<size_t>(frame_idx_ % capacity_frames_);
      const auto data_offset = circular_idx * frame_size_bytes_;
      const auto data = this->data_ptr_ + data_offset;

      Frame frame = { stream_id_,
        frame_idx_ + 1,
        this->data_ptr_ + data_offset + PAYLOAD_OFFSET,
        { 0, t_bridged, 0, 0, 0, 0 },
        lapped_frames };

      std::memcpy(&frame.timestamps[0], data, sizeof(uint64_t));

      frame_idx_++;

      return frame;
    }

    if (header_->pipeline_stage.load(std::memory_order_acquire) ==
        ShmBuffer::Header::FINISHED) {
      // The producer has finished writing data to the shared memory buffer, and
      // there are no more frames to read. Return a special frame with a
      // sequence number of UINT64_max to signal the end of the stream.
      return Frame{ stream_id_, UINT64_MAX, nullptr, { 0, 0, 0, 0, 0, 0 } };
    }

    spin_loop();
  }
}

ShmBuffer::Header*
ShmBuffer::open_shm_file(const std::string_view& name)
{
  const int fd = shm_open(name.data(), O_RDWR, 0);

  if (fd == -1) {
    throw std::runtime_error(std::format(
      "Failed to open shared memory '{}': {}", name, std::strerror(errno)));
  }

  struct stat sb;

  if (fstat(fd, &sb) == -1) {
    close(fd);
    throw std::runtime_error(
      std::format("Failed to get metadata for shared memory '{}': {}",
        name,
        std::strerror(errno)));
  }

  void* ptr =
    mmap(nullptr, sb.st_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);

  if (ptr == MAP_FAILED) {
    close(fd);
    throw std::runtime_error(std::format(
      "Failed to map shared memory '{}': {}", name, std::strerror(errno)));
  }

  close(fd);

  return static_cast<Header*>(ptr);
}
