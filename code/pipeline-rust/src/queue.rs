/// A simple queue with a fixed capacity. Rejects new items when full, but
/// allows overwriting of the oldest item.
pub struct Queue<T> {
    /// The internal storage for the queue. Each slot can either hold an item
    /// (Some(T)) or be empty (None).
    data: Vec<Option<T>>,

    /// The maximum number of items the queue can hold.
    capacity: usize,

    /// The current number of items in the queue.
    len: usize,

    /// The index of the next item to be popped (the head of the queue).
    head: usize,

    /// The index where the next item will be pushed (the tail of the queue).
    tail: usize,

    /// The number of frames that have been dropped due to the queue being full
    /// and a backpressure policy being applied.
    pub dropped_frames: u64,
}

impl<T> Queue<T> {
    /// Creates a new queue with the specified capacity.
    /// #Args
    /// * `capacity` - The maximum number of items the queue can hold.
    /// #Returns
    /// A new instance of `Queue<T>` with the specified capacity.
    pub fn new(capacity: usize) -> Self {
        let mut data = Vec::with_capacity(capacity);

        // Initialise the values to None.
        data.resize_with(capacity, || None);

        Self {
            data,
            capacity,
            len: 0,
            head: 0,
            tail: 0,
            dropped_frames: 0,
        }
    }

    /// Attempts to push an item into the queue. If the queue is full, the item
    /// is rejected.
    /// #Args
    /// * `item` - The item to be pushed into the queue.
    /// #Returns
    /// A `Result` indicating whether the push was successful. If the queue is
    /// full, the item is returned in the `Err`.
    pub fn try_push(&mut self, item: T) -> Result<(), T> {
        if self.len == self.capacity {
            return Err(item);
        }

        self.data[self.tail] = Some(item);
        self.tail = self.advance_index(self.tail);
        self.len += 1;
        Ok(())
    }

    /// Overwrites the oldest item in the queue (at the head position) with the
    /// new item.
    /// #Args
    /// * `item` - The item to be pushed into the queue, overwriting the
    ///   oldest item.
    pub fn overwrite_oldest(&mut self, item: T) {
        self.data[self.head] = Some(item);

        // Advance both head and tail to ensure the newly pushed item is at the
        // tail position.
        self.head = self.advance_index(self.head);
        self.tail = self.advance_index(self.tail);
    }

    /// Returns the oldest item from the queue, or None if the queue is empty.
    /// #Returns
    /// * An `Option<T>` containing the oldest item if the queue is not empty,
    /// or `None` if the queue is empty.
    pub fn pop(&mut self) -> Option<T> {
        if self.len == 0 {
            return None;
        }

        let item = self.data[self.head].take();
        self.head = self.advance_index(self.head);
        self.len -= 1;

        item
    }

    /// Advances the index in a circular manner.
    /// #Args
    /// * `index` - The current index to be advanced.
    /// #Returns
    /// * The next index, wrapping around to 0 if it exceeds the capacity.
    #[inline]
    fn advance_index(&self, index: usize) -> usize {
        (index + 1) % self.capacity
    }

    /// Returns the current number of items in the queue.
    /// #Returns
    /// * The number of items currently in the queue.
    #[inline]
    pub fn len(&self) -> usize {
        self.len
    }

    /// Returns the maximum capacity of the queue.
    /// #Returns
    /// * The maximum number of items the queue can hold.
    #[inline]
    pub fn capacity(&self) -> usize {
        self.capacity
    }
}
