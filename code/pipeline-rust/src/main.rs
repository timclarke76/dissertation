use std::{
    sync::{Arc, Mutex},
    thread::JoinHandle,
    time::Duration,
};

use anyhow::Result;
use clap::Parser;

mod allocator;
mod config;
mod os;
mod queue;
mod shm;
mod thread;

use allocator::TrackingAllocator;
use config::{Args, Settings};
use queue::Queue;
use shm::{SharedMemoryBuffer, SharedMemoryFrame};
use thread::{Policy, spawn_bridge_thread, spawn_inference_thread};

#[global_allocator]
static GLOBAL: TrackingAllocator = TrackingAllocator;

fn main() -> Result<()> {
    let args = Args::try_parse()?;
    let settings = Settings::try_new("settings", args)?;

    let configs = [
        (
            &settings.rgb_queue,
            SharedMemoryBuffer::RGB_STREAM_ID,
            settings.rgb_policy,
            Duration::from_millis(33),
        ),
        (
            &settings.accelerometer_queue,
            SharedMemoryBuffer::ACCELEROMETER_STREAM_ID,
            settings.accelerometer_policy,
            Duration::from_micros(500),
        ),
        (
            &settings.gyroscope_queue,
            SharedMemoryBuffer::GYROSCOPE_STREAM_ID,
            settings.gyroscope_policy,
            Duration::from_micros(400),
        ),
    ];

    let handles: Vec<_> = configs
        .into_iter()
        .flat_map(|(queue, stream_id, policy, duration)| {
            let (bridge, inference) = create_bridge_and_inference_threads(
                queue.name.as_str(),
                stream_id,
                queue.capacity_frames,
                policy,
                duration,
            );
            [bridge, inference]
        })
        .collect();

    for handle in handles {
        handle.join().unwrap();
    }

    Ok(())
}

/// Creates a bridge thread and an inference thread for a given shared memory
/// name, queue capacity, and backpressure policy.
/// #Args
/// * `stream_name` - The name of the stream to be used for shared memory and
///   telemetry.
/// * `stream_id` - The stream ID associated with the bridge thread.
/// * `queue_capacity` - The maximum number of frames that can be held in the
///   queue.
/// * `policy` - The backpressure policy to apply when the queue is full.
/// #Returns
/// A tuple containing the `JoinHandle`s of the spawned bridge and inference
/// threads.
fn create_bridge_and_inference_threads(
    stream_name: &str,
    stream_id: usize,
    queue_capacity: usize,
    policy: Policy,
    inference_time: Duration,
) -> (JoinHandle<()>, JoinHandle<()>) {
    let queue =
        Arc::new(Mutex::new(Queue::<SharedMemoryFrame>::new(queue_capacity)));

    let bridge_thread =
        spawn_bridge_thread(stream_name, stream_id, &queue, policy)
            .expect("Failed to spawn bridge thread");
    let inference_thread =
        spawn_inference_thread(stream_name, &queue, inference_time)
            .expect("Failed to spawn inference thread");

    (bridge_thread, inference_thread)
}
