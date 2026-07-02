use std::{
    sync::{
        Arc, Mutex,
        mpsc::{SyncSender, sync_channel},
    },
    thread::JoinHandle,
    time::Duration,
};

use anyhow::Result;
use clap::Parser;

mod allocator;
mod config;
mod os;
mod queue;
mod thread;

use allocator::TrackingAllocator;
use config::{Args, Policy, Settings};
use os::{ShmBuffer, ShmFrame};
use queue::Queue;
use thread::{
    spawn_bridge_thread, spawn_fusion_thread, spawn_inference_thread,
};

#[global_allocator]
static GLOBAL: TrackingAllocator = TrackingAllocator;

fn main() -> Result<()> {
    let args = Args::try_parse()?;
    let settings = Settings::try_new(args)?;

    let configs = [
        (
            &settings.rgb_queue,
            ShmBuffer::RGB_STREAM_ID,
            settings.rgb_policy,
            Duration::from_millis(33),
        ),
        (
            &settings.accelerometer_queue,
            ShmBuffer::ACCEL_STREAM_ID,
            settings.accelerometer_policy,
            Duration::from_micros(500),
        ),
        (
            &settings.gyroscope_queue,
            ShmBuffer::GYRO_STREAM_ID,
            settings.gyroscope_policy,
            Duration::from_micros(400),
        ),
    ];

    // Calculate the total size of the channel between the inference threads and
    // the fusion thread as the sum of the capacities of all queues. This
    // ensures that the channel can hold all frames from the inference threads
    // without blocking.
    let channel_size = configs
        .iter()
        .map(|(queue, _, _, _)| queue.capacity_frames)
        .sum();

    let (inference_sender, fusion_receiver) =
        sync_channel::<ShmFrame>(channel_size);

    let mut handles: Vec<_> = configs
        .into_iter()
        .flat_map(|(queue, stream_id, policy, duration)| {
            let (bridge, inference) = create_bridge_and_inference_threads(
                queue.name.as_str(),
                stream_id,
                queue.capacity_frames,
                inference_sender.clone(),
                policy,
                duration,
            );
            [bridge, inference]
        })
        .collect();

    let fusion_handle = spawn_fusion_thread(
        fusion_receiver,
        vec![
            settings.rgb_queue.name.clone(),
            settings.accelerometer_queue.name.clone(),
            settings.gyroscope_queue.name.clone(),
        ],
    )?;

    handles.push(fusion_handle);

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
/// * `inference_sender` - A `SyncSender<ShmFrame>` used to send
///   processed frames to the fusion thread.
/// * `policy` - The backpressure policy to apply when the queue is full.
/// #Returns
/// A tuple containing the `JoinHandle`s of the spawned bridge and inference
/// threads.
fn create_bridge_and_inference_threads(
    stream_name: &str,
    stream_id: usize,
    queue_capacity: usize,
    inference_sender: SyncSender<ShmFrame>,
    policy: Policy,
    inference_time: Duration,
) -> (JoinHandle<()>, JoinHandle<()>) {
    let queue = Arc::new(Mutex::new(Queue::<ShmFrame>::new(queue_capacity)));

    let bridge_thread =
        spawn_bridge_thread(stream_name, stream_id, &queue, policy)
            .expect("Failed to spawn bridge thread");

    let inference_thread = spawn_inference_thread(
        stream_name,
        &queue,
        inference_sender,
        inference_time,
    )
    .expect("Failed to spawn inference thread");

    (bridge_thread, inference_thread)
}
