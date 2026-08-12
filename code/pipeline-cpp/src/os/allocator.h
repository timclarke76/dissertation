#pragma once
#include <atomic>
#include <cstddef>

/// Global atomic counters to track allocated and freed bytes, as well as
/// allocation count.
namespace telemetry {
extern std::atomic<size_t> allocated_bytes;
extern std::atomic<size_t> allocation_count;
extern std::atomic<size_t> freed_bytes;
extern thread_local bool track_allocations;

struct ScopedToggle
{
  bool previous_state;

  ScopedToggle()
    : previous_state(track_allocations)
  {
    track_allocations = false;
  }

  ~ScopedToggle() { track_allocations = previous_state; }

  ScopedToggle(const ScopedToggle&) = delete;
  ScopedToggle& operator=(const ScopedToggle&) = delete;
};

}
