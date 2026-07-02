#pragma once

#include <algorithm>
#include <type_traits>

// clang-format off
// Platform-specific spin lock implementations.
#if defined(__x86_64__) || defined(_M_X64)
  #include <immintrin.h>
  inline void spin_loop() { _mm_pause(); }
#elif defined(__aarch64__) || defined(_M_ARM64)
  inline void spin_loop() { __asm__ volatile("yield" ::: "memory"); }
#else
  inline void spin_loop() { } // Fallback for unsupported architectures (no-op).
#endif
// clang-format on

/// \brief Performs a saturating subtraction of two unsigned numbers.
///
/// If `a` is greater than `b`, it returns the result of `a - b`. If `a` is less
/// than or equal to `b`, it returns zero instead of underflowing.
///
/// \param a The number from which `b` is to be subtracted.
/// \param b The number to be subtracted.
///
/// \return The result of the subtraction if `a > b`, otherwise zero.
template<typename T>
constexpr T
saturating_sub(T a, T b) noexcept
{
  static_assert(std::is_unsigned_v<T>, "saturating_sub is for unsigned types");
  return (a > b) ? (a - b) : T(0);
}
