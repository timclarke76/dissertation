#pragma once
#include <cstdint>
#include <variant>

/// \brief Blocks the producer until space is available in the consumer buffer.
struct BoundedQueue
{};

/// \brief Waits a short time before retrying to insert the data, with the wait
/// time doubling with each retry.
struct ExponentialBackoff
{
  /// The base wait time in nanoseconds before retrying to insert data into the
  /// consumer buffer.
  uint64_t base_nanos;

  /// The maximum wait time in nanoseconds before giving up and dropping the
  /// data.
  uint64_t max_nanos;

  /// The multiplier to apply to the wait time after each retry. For example, a
  /// multiplier of 2.0 will double the wait time after each retry.
  double multiplier;
};

/// \brief Drops the oldest data in the consumer buffer to make room for new
/// data.
struct DropOldest
{};

/// \brief Drops incoming data when the buffer is full.
struct DropNewest
{};

/// \brief Dynamically downsamples the data stream (i.e. queueing only every nth
/// event) to reduce pressure on the consumer buffer while preserving the
/// temporal continuity of the data.
struct AdaptiveDecimation
{
  /// The threshold length of the consumer buffer above which decimation is
  /// applied. When the buffer length exceeds this threshold, only every nth
  /// frame is queued, and the rest are discarded before attempting to push to
  /// the queue.
  size_t threshold;

  /// The minimum decimation ratio to apply when the consumer buffer is above
  /// the threshold. For example, a min_ratio of 2 means that only every 2nd
  /// frame will be queued when the buffer length is at the threshold. Used in
  /// conjunction with max_ratio to scale the decimation ratio based on how deep
  /// into the "danger zone" (the region between the threshold and the queue's
  /// capacity) we are.
  size_t min_ratio;

  /// The maximum decimation ratio to apply when the consumer buffer is full.
  /// For example, a max_ratio of 10 means that only every 10th frame will be
  /// queued when the buffer is full.
  size_t max_ratio;
};

/// Defines the policy for handling data when the consumer buffer is full.
using Policy = std::variant<BoundedQueue,
  ExponentialBackoff,
  DropOldest,
  DropNewest,
  AdaptiveDecimation>;
