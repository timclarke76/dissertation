use std::{
    sync::{Arc, Mutex},
    thread::JoinHandle,
    time::Duration,
};

use anyhow::Result;

mod os;
mod queue;
mod shm;
mod thread;

use queue::Queue;
use shm::SharedMemoryFrame;
use thread::{Policy, spawn_bridge_thread, spawn_inference_thread};

fn main() -> Result<()> {
    let policy = Policy::AdaptiveDecimation {
        threshold: 2,
        min_ratio: 2,
        max_ratio: 10,
    };

    let threads = vec![
        create_bridge_and_inference_threads(
            "RGB",
            3,
            policy,
            Duration::from_millis(33),
        ),
        create_bridge_and_inference_threads(
            "Accelerometer",
            160,
            policy,
            Duration::from_micros(500),
        ),
        create_bridge_and_inference_threads(
            "Gyroscope",
            200,
            policy,
            Duration::from_micros(400),
        ),
    ];

    threads.into_iter().for_each(|(bridge, inference)| {
        bridge.join().unwrap();
        inference.join().unwrap();
    });

    Ok(())
}

/// Creates a bridge thread and an inference thread for a given shared memory
/// name, queue capacity, and backpressure policy.
/// #Args
/// * `stream_name` - The name of the stream to be used for shared memory and
///   telemetry.
/// * `queue_capacity` - The maximum number of frames that can be held in the
///   queue.
/// * `policy` - The backpressure policy to apply when the queue is full.
/// #Returns
/// A tuple containing the `JoinHandle`s of the spawned bridge and inference
/// threads.
fn create_bridge_and_inference_threads(
    stream_name: &str,
    queue_capacity: usize,
    policy: Policy,
    inference_time: Duration,
) -> (JoinHandle<()>, JoinHandle<()>) {
    let queue =
        Arc::new(Mutex::new(Queue::<SharedMemoryFrame>::new(queue_capacity)));

    let bridge_thread = spawn_bridge_thread(stream_name, &queue, policy)
        .expect("Failed to spawn bridge thread");
    let inference_thread =
        spawn_inference_thread(stream_name, &queue, inference_time)
            .expect("Failed to spawn inference thread");

    (bridge_thread, inference_thread)
}
