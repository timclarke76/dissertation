use std::{
    hint::spin_loop,
    sync::{Arc, Mutex},
    thread::{self, JoinHandle, sleep},
    time::Duration,
};

use anyhow::{Context, Result};

use crate::{
    config::Policy,
    queue::Queue,
    shm::{SharedMemoryFrame, ShmBuffer},
};

/// Spawns a new thread that continuously reads frames from a shared memory
/// buffer and pushes them into a queue, applying the specified backpressure
/// policy when the queue is full.
/// #Args
/// * `shm_name` - The name of the shared memory buffer to read from.
/// * `stream_id` - The stream ID associated with this bridge.
/// * `queue` - A reference to the queue where frames will be pushed.
/// * `policy` - The backpressure policy to apply when the queue is full.
/// #Returns
/// A `Result` containing the join handle for the spawned thread, or an error if
/// the thread could not be spawned.
pub fn spawn_bridge_thread<S: AsRef<str>>(
    shm_name: S,
    stream_id: usize,
    queue: &Arc<Mutex<Queue<SharedMemoryFrame>>>,
    policy: Policy,
) -> Result<JoinHandle<()>> {
    let thread_shm_name = shm_name.as_ref().to_string();
    let queue = Arc::clone(queue);

    thread::Builder::new()
        .name(format!("bridge_{}", &thread_shm_name))
        .spawn(move || {
            let mut shm_buffer = ShmBuffer::try_new(thread_shm_name, stream_id)
                .expect("Failed to connect to {thread_shm_name}");

            let mut seq_num = 0;
            let mut decimation_counter = 0;

            loop {
                seq_num += 1;

                let mut frame = shm_buffer
                    .next_frame()
                    .expect("Failed to read next frame from shared memory");
                frame.seq_num = seq_num;

                let mut q = queue.lock().unwrap();

                if let Policy::AdaptiveDecimation {
                    threshold,
                    min_ratio,
                    max_ratio,
                } = policy
                {
                    // Dynamically downsamples the data stream (i.e. queueing
                    // only every nth event) to reduce pressure on the consumer
                    // buffer while preserving the temporal continuity of the
                    // data.

                    // When using Adaptive Decimation, and the queue's length is
                    // above a given threshold, only every nth frame is queued
                    // and the remained are discarded _before_ attempting to
                    // push to the queue. N is calculated based on how deep into
                    // the "danger zone" (the region between the threshold and
                    // the queue's capacity) we are, and scaled between a
                    // minimum and maximum ratio.
                    let len = q.len();
                    let capacity = q.capacity();

                    if len >= threshold {
                        // Determine how deep into the danger zone we are, and
                        // scale the decimation ratio accordingly.
                        // `saturating_sub` avoids underflow and wraparound.
                        let zone_size = capacity.saturating_sub(threshold);
                        let depth = len.saturating_sub(threshold);

                        // Calculate a decimation ratio scaled between min_ratio
                        // and max_ratio based on how deep into the danger zone
                        // that we are. The deeper we are, the closer we get to
                        // max_ratio. If we are at the threshold, we use
                        // min_ratio.
                        let ratio = if zone_size > 0 {
                            let numerator = depth * (max_ratio - min_ratio);
                            min_ratio + (numerator / zone_size)
                        } else {
                            // Threshold is at or above capacity, so we use the
                            // maximum ratio.
                            max_ratio
                        };

                        decimation_counter += 1;

                        if decimation_counter % ratio != 0 {
                            q.dropped_frames += 1;
                            continue; // drop
                        }
                    } else {
                        // reset
                        decimation_counter = 0;
                    }
                }

                if let Err(rejected) = q.try_push(frame) {
                    match policy {
                        Policy::BoundedQueue => {
                            // Blocks the producer until space is available in
                            // the consumer buffer.
                            drop(q);
                            let mut frame = rejected;

                            loop {
                                spin_loop();
                                let mut q = queue.lock().unwrap();

                                match q.try_push(frame) {
                                    Ok(_) => break,
                                    Err(rejected) => frame = rejected,
                                }
                            }
                        }

                        Policy::ExponentialBackoff {
                            base_nanos,
                            max_nanos,
                            multiplier,
                        } => {
                            // Waits a short time before retrying to insert the
                            // data, with the wait time multiplied with each
                            // retry.
                            drop(q);
                            let mut frame = rejected;
                            let mut backoff_nanos = base_nanos as f64;

                            loop {
                                sleep(Duration::from_nanos(
                                    backoff_nanos as u64,
                                ));

                                let mut q = queue.lock().unwrap();

                                match q.try_push(frame.clone()) {
                                    Ok(_) => break,

                                    Err(rejected) => {
                                        backoff_nanos *= multiplier;

                                        if backoff_nanos <= max_nanos as f64 {
                                            // retry
                                            frame = rejected;
                                        } else {
                                            // drop
                                            q.dropped_frames += 1;
                                            break;
                                        }
                                    }
                                }
                            }
                        }

                        Policy::DropOldest => {
                            // Drops the oldest data in the consumer buffer to
                            // make room for new data.
                            q.overwrite_oldest(rejected);
                            q.dropped_frames += 1;
                        }

                        Policy::DropNewest => {
                            // DropNewest drops incoming data when the buffer is
                            // full.
                            q.dropped_frames += 1;
                        }

                        Policy::AdaptiveDecimation { .. } => {
                            // If the Adaptive Decimation throttling is not
                            // enough to keep the queue from filling up, we drop
                            // the incoming frame.
                            q.dropped_frames += 1;
                        }
                    }
                }
            }
        })
        .with_context(|| {
            let shm_name = shm_name.as_ref().to_string();
            format!("Failed to spawn bridge thread for {shm_name}")
        })
}
