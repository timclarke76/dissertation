use std::fmt::Debug;

use anyhow::{Context, Result};
use bytemuck::Pod;
use rand::distr::uniform::SampleUniform;

use super::{buffer::ShmBuffer, pool::RandomPool};
use crate::os::now_nanos;

/// A trait that defines the behavior of an event that generates random data
/// and writes it to a shared memory buffer at a specified interval.
pub trait EventTrait {
    /// Returns the name of the event.
    fn name(&self) -> &str;

    /// Returns the seed value used to initialise the random number generator
    /// for the event.
    fn seed(&self) -> u64;

    /// Returns the length of a single frame (i.e. the number of data elements
    /// in a frame).
    fn frame_length(&self) -> usize;

    /// Returns the size of a single frame in bytes, including the timestamp.
    fn frame_size_bytes(&self) -> usize;

    /// Returns the capacity of the random data pool in frames.
    fn pool_capacity_frames(&self) -> usize;

    /// Returns the capacity of the shared memory buffer in frames.
    fn buffer_capacity_frames(&self) -> usize;

    /// Sets the next scheduled run time for the event in nanoseconds.
    fn set_next_run_nanos(&mut self, next_run_nanos: u64);

    /// Returns the next scheduled run time for the event in nanoseconds.
    fn next_run_nanos(&self) -> u64;

    /// Returns whether the pipeline is ready for the next event execution.
    fn is_pipeline_ready(&self) -> bool;

    /// Executes the event, generating random data and writing it to the shared
    /// memory buffer. This method also updates the next scheduled run time and
    /// increments the run count.
    /// #Returns
    /// A `Result` indicating success or failure. If successful, the event has
    /// been executed and the next scheduled run time has been updated. If
    /// unsuccessful, an error occurred during execution.
    fn run(&mut self) -> Result<()>;

    /// Returns the number of times the event has been executed.
    fn run_count(&self) -> u64;

    /// Returns whether the event has finished executing based on its runtime
    /// configuration. If the event has a specified runtime in frames, this
    /// method checks if the run count has reached or exceeded that limit. If no
    /// runtime is specified, the event is considered to be running indefinitely
    /// and this method will always return `false`.
    fn is_finished(&self) -> bool;
}

/// Represents an event that generates random data of type `T` and writes it to
/// a shared memory buffer at a specified interval. The event maintains a pool
/// of random values, and a shared memory buffer which acts as the destination
/// for the generated random data. The event is executed at a specified frames
/// per second (FPS) rate.
pub struct Event<T> {
    /// The name of the event.
    name: String,

    /// The seed value used to initialise the random number generator for the
    /// event.
    seed: u64,

    /// The length of a single frame in terms of the number of data elements of
    /// type `T`.
    frame_length: usize,

    /// The length of a single frame in bytes, including the timestamp.
    frame_size_bytes: usize,

    /// The capacity of the random data pool in frames.
    pool_capacity_frames: usize,

    /// The pool of random values of type `T`, generated using a uniform
    /// distribution.
    pool: RandomPool<T>,

    /// The capacity of the shared memory buffer in frames.
    buffer_capacity_frames: usize,

    /// The shared memory buffer which is the destination for the generated
    /// random data.
    buffer: ShmBuffer,

    /// The interval between event executions in nanoseconds, calculated based
    /// on the specified frames per second (FPS) rate.
    interval_nanos: u64,

    /// The next scheduled run time for the event in nanoseconds.
    next_run_nanos: u64,

    /// The number of times the event has been executed.
    run_count: u64,

    /// How long to generate events before exiting (in frames). If not provided,
    /// the event will run indefinitely.
    runtime_frames: Option<u64>,
}

impl<T> Event<T>
where
    T: SampleUniform + Pod + Debug,
{
    /// The size of the timestamp in bytes.
    const TIMESTAMP_SIZE_BYTES: usize = std::mem::size_of::<u64>();

    /// Creates a new `Event` instance with the specified arguments.
    /// #Args
    /// * `name`: The name of the event.
    /// * `seed`: The seed value for the random number generator.
    /// * `frame_length`: The length of a single frame in terms of the number of
    ///   data elements of type `T`.
    /// * `pool_capacity_frames`: The capacity of the random data pool in
    ///   frames.
    /// * `buffer_capacity_frames`: The capacity of the shared memory buffer in
    ///   frames.
    /// * `fps`: The frames per second (FPS) rate for the event.
    /// * `min`: The minimum value for the uniform distribution of random data.
    /// * `max`: The maximum value for the uniform distribution of random data.
    /// #Returns
    /// A `Result` containing the new `Event` instance if successful, or an
    /// error if any of the parameters are invalid or if the random data pool or
    /// shared memory buffer could not be created.
    pub fn try_new(
        name: impl Into<String>,
        seed: u64,
        frame_length: usize,
        pool_capacity_frames: usize,
        buffer_capacity_frames: usize,
        fps: f32,
        min: T,
        max: T,
        runtime_seconds: Option<usize>,
    ) -> Result<Self> {
        let name = name.into();

        let frame_data_size_bytes = frame_length
            .checked_mul(std::mem::size_of::<T>())
            .with_context(|| {
                format!(
                    "Requested frame size ({frame_length} frames * \
                    {} bytes per frame) larger than usize::MAX",
                    std::mem::size_of::<T>()
                )
            })?;

        let frame_size_bytes = frame_data_size_bytes
            .checked_add(Self::TIMESTAMP_SIZE_BYTES)
            .with_context(|| {
                format!(
                    "Requested frame size ({frame_data_size_bytes} bytes + \
                    {} bytes timestamp) larger than usize::MAX",
                    Self::TIMESTAMP_SIZE_BYTES
                )
            })?;

        // Round the frame size up to the nearest multiple of 64 bytes for cache
        // line alignment.
        let frame_size_bytes = frame_size_bytes.checked_next_multiple_of(64)
            .with_context(|| {
                format!(
                    "Requested frame size ({frame_size_bytes} bytes) larger \
                    than usize::MAX when rounded up to the nearest multiple of \
                    64 bytes"
                )
            })?;

        // RandomPool knows nothing about the frame size, so we calculate the
        // total pool capacity, in terms of the total number of data elements of
        // type T, here.
        let pool_capacity = pool_capacity_frames
            .checked_mul(frame_length)
            .with_context(|| {
                format!(
                    "Requested pool capacity ({pool_capacity_frames} frames * \
                    {frame_length} frame length) larger than usize::MAX"
                )
            })?;

        let pool = RandomPool::try_new(pool_capacity, min, max, seed)
            .with_context(|| {
                format!(
                    "Failed to create RandomPool with capacity \
                    {pool_capacity} for event '{name}'"
                )
            })?;

        // ShmBuffer needs to know the frame size to create each frame's header,
        // and therefore can calculate its own total size.
        let buffer =
            ShmBuffer::try_new(&name, frame_size_bytes, buffer_capacity_frames)
                .with_context(|| {
                    format!(
                        "Failed to create ShmBuffer of \
                {buffer_capacity_frames} frames for event '{name}'"
                    )
                })?;

        Ok(Self {
            name,
            seed,
            frame_length,
            frame_size_bytes,
            pool_capacity_frames,
            pool,
            buffer_capacity_frames,
            buffer,
            interval_nanos: (1_000_000_000.0 / fps) as u64,
            next_run_nanos: 0,
            run_count: 0,
            runtime_frames: runtime_seconds.map(|s| (s as f32 * fps) as u64),
        })
    }
}

impl<T> EventTrait for Event<T>
where
    T: SampleUniform + Pod + Debug,
{
    /// Returns the name of the event.
    #[inline]
    fn name(&self) -> &str {
        &self.name
    }

    /// Returns the seed value used to initialise the random number generator
    /// for the event.
    #[inline]
    fn seed(&self) -> u64 {
        self.seed
    }

    /// Returns the length of a single frame (i.e. the number of data elements
    /// in a frame).
    #[inline]
    fn frame_length(&self) -> usize {
        self.frame_length
    }

    /// Returns the size of a single frame in bytes, including the timestamp.
    #[inline]
    fn frame_size_bytes(&self) -> usize {
        self.frame_size_bytes
    }

    /// Returns the capacity of the random data pool in frames.
    #[inline]
    fn pool_capacity_frames(&self) -> usize {
        self.pool_capacity_frames
    }

    /// Returns the capacity of the shared memory buffer in frames.
    #[inline]
    fn buffer_capacity_frames(&self) -> usize {
        self.buffer_capacity_frames
    }

    /// Sets the next scheduled run time for the event in nanoseconds.
    #[inline]
    fn set_next_run_nanos(&mut self, next_run_nanos: u64) {
        self.next_run_nanos = next_run_nanos;
    }

    /// Returns the next scheduled run time for the event in nanoseconds.
    #[inline]
    fn next_run_nanos(&self) -> u64 {
        self.next_run_nanos
    }

    /// Executes the event, generating random data and writing it to the shared
    /// memory buffer. This method also updates the next scheduled run time and
    /// increments the run count.
    /// #Returns
    /// A `Result` indicating success or failure. If successful, the event has
    /// been executed and the next scheduled run time has been updated. If
    /// unsuccessful, an error occurred during execution.
    fn run(&mut self) -> Result<()> {
        let data = self.pool.next(self.frame_length).with_context(|| {
            format!(
                "Unable to read {} item from pool for event '{}'",
                self.frame_length, self.name
            )
        })?;

        let now = now_nanos().with_context(|| {
            format!("Unable to get current time to run event '{}'", self.name)
        })?;

        let slice = self.buffer.get_mut_slice();
        slice[0..Event::<T>::TIMESTAMP_SIZE_BYTES]
            .clone_from_slice(&now.to_ne_bytes());

        let data = bytemuck::cast_slice(&data);
        let data_start = Event::<T>::TIMESTAMP_SIZE_BYTES;
        let data_end = data_start + data.len();
        slice[data_start..data_end].clone_from_slice(data);
        self.buffer.commit();

        self.run_count += 1;
        self.next_run_nanos += self.interval_nanos;

        if self.is_finished() {
            self.buffer.set_pipeline_finished();
        }

        Ok(())
    }

    /// Returns the number of times the event has been executed.
    #[inline]
    fn run_count(&self) -> u64 {
        self.run_count
    }

    /// Returns whether the pipeline is ready for the next event execution.
    fn is_pipeline_ready(&self) -> bool {
        self.buffer.is_pipeline_ready()
    }

    /// Returns whether the event has finished executing based on its runtime
    /// configuration. If the event has a specified runtime in frames, this
    /// method checks if the run count has reached or exceeded that limit. If no
    /// runtime is specified, the event is considered to be running indefinitely
    /// and this method will always return `false`.
    fn is_finished(&self) -> bool {
        if let Some(runtime_frames) = self.runtime_frames {
            self.run_count() >= runtime_frames
        } else {
            false
        }
    }
}
