#pragma once
#include <memory>
#include <semaphore>

#include "blockingconcurrentqueue.h"

/// \brief Represents the state of a channel, including the queue and semaphore
/// for managing slots.
template<typename T>
struct ChannelState
{
  /// The concurrent queue for storing items of type T.
  moodycamel::BlockingConcurrentQueue<T> queue;

  /// The counting semaphore for managing available slots in the channel.
  std::counting_semaphore<> slots;

  /// \brief Constructs a new ChannelState with the specified number of slots.
  /// \param slots The number of slots available in the channel.
  explicit ChannelState(const size_t slots)
    : queue(slots)
    , slots(slots)
  {
  }
};

/// \brief Represents the sending end of a channel, allowing items of type T to
/// be sent to the receiving end.
template<typename T>
class Sender
{
public:
  /// \brief Constructs a new Sender with the specified shared state.
  ///
  /// \param state A shared pointer to the ChannelState that manages the queue
  /// and semaphore for the channel.
  explicit Sender(std::shared_ptr<ChannelState<T>> state)
    : state_(state)
  {
  }

  /// \brief Move constructor for Sender.
  /// \param other The Sender to move from.
  Sender(Sender&& other) noexcept
    : state_(std::move(other.state_))
  {
  }

  /// \brief Move assignment operator for Sender.
  /// \param other The Sender to move from.
  Sender& operator=(Sender&& other) noexcept
  {
    if (this != &other) {
      state_ = std::move(other.state_);
    }

    return *this;
  }

  /// \brief Copy constructor for Sender.
  /// \param other The Sender to copy from.
  Sender(const Sender&) = default;

  /// \brief Copy assignment operator for Sender.
  /// \param other The Sender to copy from.
  Sender& operator=(const Sender&) = default;

  /// \brief Sends a value of type T to the receiving end of the channel.
  /// \param value The value to send.
  /// \return True if the value was successfully sent, false otherwise.
  bool send(T value)
  {
    state_->slots.acquire();
    return state_->queue.enqueue(std::move(value));
  }

private:
  /// \brief A shared pointer to the ChannelState that manages the queue and
  /// semaphore for the channel.
  std::shared_ptr<ChannelState<T>> state_;
};

/// \brief Represents the receiving end of a channel, allowing items of type T
/// to be received from the sending end.
template<typename T>
class Receiver
{
public:
  /// \brief Constructs a new Receiver with the specified shared state.
  ///
  /// \param state A shared pointer to the ChannelState that manages the queue
  /// and semaphore for the channel.
  explicit Receiver(std::shared_ptr<ChannelState<T>> state)
    : state_(state)
  {
  }

  /// \brief Move constructor for Receiver.
  /// \param other The Receiver to move from.
  Receiver(Receiver&& other) noexcept
    : state_(std::move(other.state_))
  {
  }

  /// \brief Move assignment operator for Receiver.
  /// \param other The Receiver to move from.
  Receiver& operator=(Receiver&& other) noexcept
  {
    if (this != &other) {
      state_ = std::move(other.state_);
    }

    return *this;
  }

  // Delete copy constructor and copy assignment operator to prevent copying of
  // Receiver instances.
  Receiver(const Receiver&) = delete;
  Receiver& operator=(const Receiver&) = delete;

  /// \brief Receives a value of type T from the sending end of the channel.
  /// \return The received value of type T.
  T receive()
  {
    T value;
    state_->queue.wait_dequeue(value);
    state_->slots.release();
    return value;
  }

private:
  /// \brief A shared pointer to the ChannelState that manages the queue and
  /// semaphore for the channel.
  std::shared_ptr<ChannelState<T>> state_;
};

/// \brief Creates a new channel with the specified number of slots and returns
/// a pair of Sender and Receiver instances for sending and receiving items of
/// type T.
///
/// \param slots The number of slots available in the channel.
/// \return A pair containing the Sender and Receiver instances for the channel.
template<typename T>
std::pair<Sender<T>, Receiver<T>>
make_channel(size_t slots)
{
  auto state = std::make_shared<ChannelState<T>>(slots);
  return { Sender<T>(state), Receiver<T>(state) };
}
