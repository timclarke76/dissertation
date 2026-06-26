use std::fmt::Debug;

use anyhow::{Context, Result};
use bytemuck::Pod;

use rand::{
    RngExt, SeedableRng,
    distr::uniform::{SampleUniform, Uniform},
    rngs::SmallRng,
};

/// A pool of random values of type T, generated using a uniform distribution.
pub struct RandomPool<T> {
    /// The random values in the pool.
    data: Vec<T>,

    /// The index of the next value to read from the pool.
    next_read_index: usize,
}

impl<T> RandomPool<T>
where
    T: SampleUniform + Pod + Debug,
{
    /// Creates a new RandomPool with the specified capacity, minimum and
    /// maximum values, and seed for the random number generator.
    /// #Args
    /// * `capacity`: The number of random values to generate in the pool.
    /// * `min`: The minimum value for the uniform distribution.
    /// * `max`: The maximum value for the uniform distribution.
    /// * `seed`: The seed for the random number generator.
    /// #Returns
    /// A `Result` containing the `RandomPool` if successful, or an error if the
    /// uniform distribution could not be created.
    pub fn try_new(capacity: usize, min: T, max: T, seed: u64) -> Result<Self> {
        let distribution =
            Uniform::new_inclusive(min, max).with_context(|| {
                format!(
                    "Failed to create uniform distribution for \
                    RandomPool with min: {min:?}, max: {max:?}"
                )
            })?;

        let rng = SmallRng::seed_from_u64(seed);
        let rng_iter = rng.sample_iter(distribution);

        Ok(RandomPool {
            data: rng_iter.take(capacity).collect(),
            next_read_index: 0,
        })
    }

    /// Returns the next `len` random values from the pool, wrapping around to
    /// the beginning if necessary.
    /// #Args
    /// * `len`: The number of random values to retrieve from the pool.
    /// #Returns
    /// An `Option` containing a slice of the next `len` random values, or
    /// `None` if `len` is greater than the pool's capacity.
    pub fn next(&mut self, len: usize) -> Option<&[T]> {
        if len > self.data.len() {
            return None;
        }

        if self.next_read_index + len > self.data.len() {
            // The requested length exceeds the remaining values in the pool,
            // so wrap around to the beginning of the pool.
            self.next_read_index = 0;
        }

        let start = self.next_read_index;
        self.next_read_index += len;

        Some(&self.data[start..self.next_read_index])
    }
}
