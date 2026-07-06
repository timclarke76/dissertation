import queue
from typing import TypeVar, Generic, Tuple, Optional

T = TypeVar('T')


class ChannelState(Generic[T]):
    """Represents the state of a channel. The number of slots is managed by the
    queue itself."""

    def __init__(self, slots: int):
        """Constructs a new ChannelState with the specified number of slots.

        Args:
            slots: The number of slots available in the channel."""

        self.queue: queue.Queue[T] = queue.Queue(maxsize=slots)


class Sender(Generic[T]):
    """Represents the sending end of a channel, allowing items of type T to be
    sent to the receiving end."""

    def __init__(self, state: ChannelState[T]):
        """Constructs a new Sender with the specified shared state.

        Args:
            state: A reference to the ChannelState that manages the queue for
            the channel."""

        self._state = state

    def send(self, value: T):
        """Sends a value of type T to the receiving end of the channel. Throws
        an exception if the channel is full.

        Args:
            value: The value to send."""

        self._state.queue.put(value, block=True)


class Receiver(Generic[T]):
    """Represents the receiving end of a channel, allowing items of type T to be
    received from the sending end."""

    def __init__(self, state: ChannelState[T]):
        """Constructs a new Receiver with the specified shared state.

        Args:
            state: A reference to the ChannelState that manages the queue for
            the channel."""

        self._state = state

    def receive(self) -> T:
        """Receives a value of type T from the sending end of the channel.

        Returns:
            The received value of type T."""

        return self._state.queue.get(block=True)

    def try_receive(self) -> Optional[T]:
        """Attempts to receive a value of type T from the sending end of the
        channel without blocking. If the queue is empty, returns an empty
        optional.

        Returns:
            An optional containing the received value of type T if successful,
            or an empty optional if the queue is empty."""
        try:
            return self._state.queue.get(block=False)
        except queue.Empty:
            return None


def make_channel(slots: int) -> Tuple[Sender[T], Receiver[T]]:
    """Creates a new channel with the specified number of slots and returns a
    pair of Sender and Receiver instances for sending and receiving items of
    type T.

    Args:
        slots: The number of slots available in the channel.

    Returns:
        A tuple containing the Sender and Receiver instances for the channel."""

    state = ChannelState[T](slots)
    return Sender(state), Receiver(state)
