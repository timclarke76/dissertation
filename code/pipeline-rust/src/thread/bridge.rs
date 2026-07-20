use std::{
    hint::spin_loop,
    sync::{Arc, Mutex},
    thread::{self, JoinHandle, sleep},
    time::Duration,
};

use anyhow::{Context, Result};

use crate::{
    config::Policy,
    os::{ShmBuffer, ShmFrame},
    queue::Queue,
};

/// Spawns a new thread that continuously reads frames from a shared memory
/// buffer and pushes them into a queue, applying the specified backpressure
/// policy when the queue is full.
///
/// * `shm_name` - The name of the shared memory buffer to read from.
/// * `stream_id` - The stream ID associated with this bridge.
/// * `queue` - A reference to the `Queue` where frames will be pushed.
/// * `policy` - The backpressure `Policy` to apply when the queue is full.
///
/// Returns a `Result` containing the join handle for the spawned thread, or an
/// error if the thread could not be spawned.
pub fn spawn_bridge_thread(
    shm_name: impl Into<String>,
    stream_id: usize,
    queue: &Arc<Mutex<Queue<ShmFrame>>>,
    policy: Policy,
) -> Result<JoinHandle<()>> {
    let shm_name = shm_name.into();
    let queue = Arc::clone(queue);

    thread::Builder::new()
        .name(format!("bridge_{}", shm_name))
        .spawn({
            let shm_name = shm_name.clone();
            move || {
                let mut shm_buffer = ShmBuffer::try_new(shm_name, stream_id)
                    .expect("Failed to connect to {shm_name}");

                let mut decimation_counter = 0;

                loop {
                    let frame = shm_buffer
                        .next_frame()
                        .expect("Failed to read next frame from shared memory");

                    let mut q = queue.lock().unwrap();
                    q.lapped_frames += frame.lapped_frames;

                    if frame.seq_num == u64::MAX {
                        // The generator stream has ended, so push the final
                        // frame to the queue and exit the loop.
                        if let Err(rejected) = q.try_push(frame) {
                            q.overwrite_oldest(rejected);
                        }

                        break;
                    }

                    if let Policy::AdaptiveDecimation {
                        threshold,
                        min_ratio,
                        max_ratio,
                    } = policy
                    {
                        // Dynamically downsamples the data stream (i.e.
                        // queueing only every nth event) to reduce pressure on
                        // the consumer buffer while preserving the temporal
                        // continuity of the data.

                        // When using Adaptive Decimation, and the queue's
                        // length is above a given threshold, only every nth
                        // frame is queued and the remained are discarded
                        // _before_ attempting to push to the queue. N is
                        // calculated based on how deep into the "danger zone"
                        // (the region between the threshold and the queue's
                        // capacity) we are, and scaled between a minimum and
                        // maximum ratio.

                        if q.len() >= threshold {
                            // Determine how deep into the danger zone we are,
                            // and scale the decimation ratio accordingly.
                            // `saturating_sub` avoids underflow and wraparound.
                            let zone_size =
                                q.capacity().saturating_sub(threshold);
                            let depth = q.len().saturating_sub(threshold);

                            // Calculate a decimation ratio scaled between
                            // min_ratio and max_ratio based on how deep into
                            // the danger zone that we are. The deeper we are,
                            // the closer we get to max_ratio. If we are at the
                            // threshold, we use min_ratio.
                            let ratio = if zone_size > 0 {
                                let numerator = depth * (max_ratio - min_ratio);
                                min_ratio + (numerator / zone_size)
                            } else {
                                // Threshold is at or above capacity, so we use
                                // the maximum ratio.
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
                                // Blocks the producer until space is available
                                // in the consumer buffer.
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
                                // Waits a short time before retrying to insert
                                // the data, with the wait time multiplied with
                                // each retry.
                                drop(q);
                                let mut frame = rejected;
                                let mut backoff_nanos = base_nanos as f64;
                                let mut accumulated_nanos = 0.0;

                                loop {
                                    if accumulated_nanos > max_nanos {
                                        // drop
                                        let mut q = queue.lock().unwrap();
                                        q.dropped_frames += 1;
                                        break;
                                    }

                                    sleep(Duration::from_nanos(
                                        backoff_nanos as u64,
                                    ));

                                    let mut q = queue.lock().unwrap();

                                    match q.try_push(frame.clone()) {
                                        Ok(_) => break,

                                        Err(rejected) => {
                                            accumulated_nanos += backoff_nanos;
                                            backoff_nanos *= multiplier;
                                            frame = rejected;
                                        }
                                    }
                                }
                            }

                            Policy::DropOldest => {
                                // Drops the oldest data in the consumer buffer
                                // to make room for new data.
                                q.overwrite_oldest(rejected);
                                q.dropped_frames += 1;
                            }

                            Policy::DropNewest => {
                                // DropNewest drops incoming data when the
                                // buffer is full.
                                q.dropped_frames += 1;
                            }

                            Policy::AdaptiveDecimation { .. } => {
                                // If the Adaptive Decimation throttling is not
                                // enough to keep the queue from filling up, we
                                // drop the oldest frame to make room for the
                                // new frame.
                                q.overwrite_oldest(rejected);
                                q.dropped_frames += 1;
                            }
                        }
                    }
                }
            }
        })
        .with_context(|| {
            format!("Failed to spawn bridge thread for {shm_name}")
        })
}
