#pragma once
#include <memory>
#include <mutex>
#include <optional>
#include <queue>

/// \brief A simple queue with a fixed capacity.
///
/// Rejects new items when full, but allows overwriting of the oldest item.
template<typename T>
class Queue
{
public:
  /// \brief Constructs a new Queue with the specified capacity.
  ///
  /// \param capacity The maximum number of elements the queue can hold.
  explicit Queue(size_t capacity)
    : data_(capacity, std::nullopt)
    , capacity_(capacity)
  {
  }

  /// \brief Attempts to push an item into the queue.
  ///
  /// If the queue is full, the item is rejected.
  ///
  /// \param item The item to push onto the queue.
  /// \return True if the item was successfully pushed, or false if the queue is
  /// full.
  bool try_push(T const item)
  {
    if (len_ == capacity_) {
      return false;
    }

    data_[tail_] = item;
    tail_ = advance_index(tail_);
    len_++;

    return true;
  }

  /// \brief Overwrites the oldest item in the queue (at the head position) with
  /// the new item.
  ///
  /// \param item The item to be pushed into the queue, overwriting the oldest
  /// item.
  void overwrite_oldest(T const item)
  {
    data_[head_] = item;
    head_ = advance_index(head_);
    tail_ = advance_index(tail_);
  }

  /// \brief Returns the oldest item from the queue, or None if the queue is
  /// empty.
  ///
  /// \return An optional containing the oldest item if the queue is not empty;
  /// otherwise, an empty optional.
  std::optional<T> pop()
  {
    if (len_ == 0)
      return std::nullopt;

    auto item = std::move(data_[head_]);
    data_[head_] = std::nullopt;
    head_ = advance_index(head_);
    len_--;

    return item;
  }

  /// \brief Returns the current number of items in the queue.
  /// \return The number of items currently in the queue.
  size_t len() const { return len_; }

  /// \brief Returns the maximum capacity of the queue.
  /// \return The maximum number of items the queue can hold.
  size_t capacity() const { return capacity_; }

  /// \brief Increments the count of lapped frames by the specified amount.
  /// \param count The number of lapped frames to add to the total.
  void increment_lapped_frames(const uint64_t count) { lapped_frames += count; }

  /// \brief Returns the total number of lapped frames.
  /// \return The total number of frames that have been lapped by the producer.
  uint64_t get_lapped_frames() const { return lapped_frames; }

  /// \brief Increments the count of dropped frames by the specified amount.
  /// \param count The number of dropped frames to add to the total.
  void increment_dropped_frames(const uint64_t count = 1)
  {
    dropped_frames += count;
  }

  /// \brief Returns the total number of dropped frames.
  /// \return The total number of frames that have been dropped due to the queue
  /// being full and a backpressure policy being applied.
  uint64_t get_dropped_frames() const { return dropped_frames; }

  /// \brief Returns the queue's mutex.
  /// \return A reference to the queue's mutex.
  std::mutex& get_mutex() { return mutex; }

private:
  /// \brief Advances the index in a circular manner.
  /// \param index The current index to be advanced.
  /// \returns the next index, wrapping around to 0 if it exceeds the capacity.
  size_t advance_index(size_t index) const { return (index + 1) % capacity_; }

  /// The internal storage for the queue. Each slot can either hold an optional
  /// item of type T or be empty (std::nullopt).
  std::vector<std::optional<T>> data_;

  /// The maximum number of items the queue can hold.
  size_t capacity_;

  /// The current number of items in the queue.
  size_t len_ = 0;

  /// The index of the next item to be popped (the head of the queue).
  size_t head_ = 0;

  /// The index where the next item will be pushed (the tail of the queue).
  size_t tail_ = 0;

  /// The number of frames that have been lapped by the producer.
  uint64_t lapped_frames = 0;

  /// The number of frames that have been dropped due to the queue being full
  /// and a backpressure policy being applied.
  uint64_t dropped_frames = 0;

  /// A mutex to ensure thread-safe access to the queue.
  std::mutex mutex;
};
