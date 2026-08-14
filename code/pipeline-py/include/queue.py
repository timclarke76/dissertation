import threading
from typing import TypeVar, Generic, Optional

T = TypeVar('T')


class Queue(Generic[T]):
    """A simple queue with a fixed capacity. Rejects new items when full, but
    allows overwriting of the oldest item."""

    def __init__(self, capacity: int):
        """Constructs a new queue with the specified capacity.

        Args:
            capacity: The maximum number of items the queue can hold.

        Returns:
            A new instance of Queue with the specified capacity."""

        self.data = [None] * capacity
        self.capacity = capacity
        self.len = 0
        self.head = 0
        self.tail = 0
        self.lapped_frames = 0
        self.dropped_frames = 0
        self.lock = threading.Lock()

    def try_push(self, item: T) -> bool:
        """Attempts to push an item into the queue. If the queue is full, the
        item is rejected.

        Args:
            item: The item to be pushed into the queue.

        Returns:
            True if the push was successful. False otherwise."""

        if self.len == self.capacity:
            return False

        self.data[self.tail] = item
        self.tail = self._advance_index(self.tail)
        self.len += 1
        return True

    def overwrite_oldest(self, item: T) -> None:
        """Overwrites the oldest item in the queue (at the head position) with
        the new item.

        Args:
            item: The item to be pushed into the queue, overwriting the oldest
            item."""

        self.data[self.head] = item
        self.head = self._advance_index(self.head)
        self.tail = self._advance_index(self.tail)

    def pop(self) -> Optional[T]:
        """Returns the oldest item from the queue, or None if the queue is
        empty.

        Returns:
            An optional containing the oldest item in the queue, or None if the
            queue is empty."""

        if self.len == 0:
            return None

        item = self.data[self.head]
        self.data[self.head] = None
        self.head = self._advance_index(self.head)
        self.len -= 1

        return item

    def _advance_index(self, index: int) -> int:
        """Advances the index in a circular manner.

        Args:
            index: The current index to be advanced.

        Returns the next index, wrapping around to 0 if it exceeds the
        capacity."""

        return (index + 1) % self.capacity
