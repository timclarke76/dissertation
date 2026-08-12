#include <cstdlib>
#include <new>

#include "allocator.h"

/// Global atomic counters to track allocated and freed bytes, as well as
/// allocation count.
namespace telemetry {
std::atomic<size_t> allocated_bytes{ 0 };
std::atomic<size_t> allocation_count{ 0 };
std::atomic<size_t> freed_bytes{ 0 };

thread_local bool track_allocations = true;
}

/// \brief Global operator new overload to track memory allocations.
///
/// \param count The number of bytes to allocate.
/// \return A pointer to the allocated memory.
void*
operator new(std::size_t count)
{
  if (telemetry::track_allocations) {
    telemetry::allocated_bytes.fetch_add(count, std::memory_order_relaxed);
    telemetry::allocation_count.fetch_add(1, std::memory_order_relaxed);
  }

  if (void* ptr = std::malloc(count)) {
    return ptr;
  }

  throw std::bad_alloc{};
}

/// \brief Global operator new overload to track memory allocations.
///
/// \param count The number of bytes to allocate.
/// \return A pointer to the allocated memory.
void*
operator new[](std::size_t count)
{
  return operator new(count);
}

/// \brief Global operator delete overload to track memory deallocations.
///
/// No exception variation.
///
/// \param ptr Pointer to the memory to deallocate.
/// \param count The number of bytes to deallocate.
void
operator delete(void* ptr, std::size_t count) noexcept
{
  if (telemetry::track_allocations) {
    telemetry::freed_bytes.fetch_add(count, std::memory_order_relaxed);
  }

  std::free(ptr);
}

/// \brief Global operator delete overload to track memory deallocations.
///
/// \param ptr Pointer to the memory to deallocate.
/// \param count The number of bytes to deallocate.
void
operator delete[](void* ptr, std::size_t count) noexcept
{
  operator delete(ptr, count);
}

/// \brief Global operator delete overload.
///
/// Required for safety.
///
/// \param ptr Pointer to the memory to deallocate.
void
operator delete(void* ptr) noexcept
{
  std::free(ptr);
}

/// \brief Global operator delete overload.
///
/// Required for safety.
///
/// \param ptr Pointer to the memory to deallocate.
void
operator delete[](void* ptr) noexcept
{
  std::free(ptr);
}

/// \brief Global operator new overload to track memory allocations with
/// alignment.
///
/// Required for C++17 aligned allocation.
///
/// \param count The number of bytes to allocate.
/// \param al The alignment requirement for the allocation.
/// \return A pointer to the allocated memory.
void*
operator new(std::size_t count, std::align_val_t al)
{
  if (telemetry::track_allocations) {
    telemetry::allocated_bytes.fetch_add(count, std::memory_order_relaxed);
    telemetry::allocation_count.fetch_add(1, std::memory_order_relaxed);
  }

  // Linux fix: round up 'count' to the nearest multiple of 'alignment'
  std::size_t alignment = static_cast<std::size_t>(al);
  std::size_t fit_size = (count + alignment - 1) & ~(alignment - 1);

  if (void* ptr = ::aligned_alloc(alignment, fit_size)) {
    return ptr;
  }

  throw std::bad_alloc{};
}

/// \brief Global operator new overload to track array memory allocations with
/// alignment.
///
/// \param count The number of bytes to allocate.
/// \param al The alignment requirement for the allocation.
/// \return A pointer to the allocated memory.
void*
operator new[](std::size_t count, std::align_val_t al)
{
  return operator new(count, al);
}

/// \brief Global operator delete overload to track memory deallocations with
/// alignment.
///
/// Required for C++17 aligned deallocation.
///
/// \param ptr Pointer to the memory to deallocate.
/// \param count The number of bytes to deallocate.
/// \param al The alignment requirement for the deallocation.
void
operator delete(void* ptr,
  std::size_t count,
  [[maybe_unused]] std::align_val_t al) noexcept
{
  if (telemetry::track_allocations) {
    telemetry::freed_bytes.fetch_add(count, std::memory_order_relaxed);
  }

  std::free(ptr);
}

/// \brief Global operator delete overload to track array memory deallocations
/// with alignment.
///
/// \param ptr Pointer to the memory to deallocate.
/// \param count The number of bytes to deallocate.
/// \param al The alignment requirement for the deallocation.
void
operator delete[](void* ptr, std::size_t count, std::align_val_t al) noexcept
{
  operator delete(ptr, count, al);
}
