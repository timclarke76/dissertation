use std::alloc::{GlobalAlloc, Layout, System};
use std::cell::Cell;
use std::sync::atomic::{AtomicUsize, Ordering};

/// A custom global allocator that tracks memory allocations and deallocations.
pub struct TrackingAllocator;

/// Global atomic counters to track allocated and freed bytes, as well as
/// allocation count.
pub static ALLOCATED_BYTES: AtomicUsize = AtomicUsize::new(0);
pub static FREED_BYTES: AtomicUsize = AtomicUsize::new(0);
pub static ALLOCATION_COUNT: AtomicUsize = AtomicUsize::new(0);

thread_local! {
    pub static TRACK_ALLOCATIONS: Cell<bool> = Cell::new(true);
}

pub struct ScopedToggle {
    previous_state: bool,
}

impl ScopedToggle {
    pub fn new() -> Self {
        let previous_state = TRACK_ALLOCATIONS.with(|t| t.get());
        TRACK_ALLOCATIONS.with(|t| t.set(false));

        Self { previous_state }
    }
}

impl Drop for ScopedToggle {
    fn drop(&mut self) {
        TRACK_ALLOCATIONS.with(|t| t.set(self.previous_state));
    }
}

unsafe impl GlobalAlloc for TrackingAllocator {
    /// Allocates memory and updates the tracking counters.
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let track = TRACK_ALLOCATIONS.try_with(|t| t.get()).unwrap_or(true);

        if track {
            // Update the allocated bytes and allocation count atomically. No
            // synchronisation is needed for these counters, so
            // `Ordering::Relaxed` can be used.
            ALLOCATED_BYTES.fetch_add(layout.size(), Ordering::Relaxed);
            ALLOCATION_COUNT.fetch_add(1, Ordering::Relaxed);
        }

        // Use the system allocator to perform the actual allocation.
        unsafe { System.alloc(layout) }
    }

    /// Deallocates memory and updates the tracking counter.
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        let track = TRACK_ALLOCATIONS.try_with(|t| t.get()).unwrap_or(true);

        if track {
            // Update the freed bytes counter atomically.
            FREED_BYTES.fetch_add(layout.size(), Ordering::Relaxed);
        }

        // Use the system allocator to perform the actual deallocation.
        unsafe { System.dealloc(ptr, layout) }
    }
}
