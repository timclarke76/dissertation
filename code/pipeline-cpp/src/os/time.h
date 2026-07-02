#pragma once
#include <chrono>
#include <cstdint>

/// Returns the current monotonic time in nanoseconds.
///
/// \return A Result containing the current monotonic time in nanoseconds, or an
/// error if the operation fails.
inline uint64_t
current_time_nanos()
{
  return std::chrono::duration_cast<std::chrono::nanoseconds>(
    std::chrono::steady_clock::now().time_since_epoch())
    .count();
}
