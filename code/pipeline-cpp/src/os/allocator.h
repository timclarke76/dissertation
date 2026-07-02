#pragma once
#include <atomic>
#include <cstddef>

/// Global atomic counters to track allocated and freed bytes, as well as
/// allocation count.
namespace telemetry {
extern std::atomic<size_t> allocated_bytes;
extern std::atomic<size_t> allocation_count;
extern std::atomic<size_t> freed_bytes;
}
