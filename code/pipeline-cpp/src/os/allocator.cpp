#include <cstdlib>
#include <new>

#include "allocator.h"

/// Global atomic counters to track allocated and freed bytes, as well as
/// allocation count.
namespace telemetry {
std::atomic<size_t> allocated_bytes{ 0 };
std::atomic<size_t> allocation_count{ 0 };
std::atomic<size_t> freed_bytes{ 0 };
}

/// \brief Global operator new overload to track memory allocations.
///
/// \param count The number of bytes to allocate.
/// \return A pointer to the allocated memory.
void*
operator new(std::size_t count)
{
  telemetry::allocated_bytes.fetch_add(count, std::memory_order_relaxed);
  telemetry::allocation_count.fetch_add(1, std::memory_order_relaxed);

  if (void* ptr = std::malloc(count)) {
    return ptr;
  }

  throw std::bad_alloc{};
}

/// \brief Global operator delete overload to track memory deallocations.
///
/// \param ptr Pointer to the memory to deallocate.
/// \param count The number of bytes to deallocate.
void
operator delete(void* ptr, std::size_t count) noexcept
{
  telemetry::freed_bytes.fetch_add(count, std::memory_order_relaxed);
  std::free(ptr);
}

/// \brief Global operator delete overload to handle deallocations without size.
///
/// \param ptr Pointer to the memory to deallocate.
void
operator delete(void* ptr) noexcept
{
  std::free(ptr);
}
