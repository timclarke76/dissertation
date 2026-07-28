use std::{
    sync::{
        Arc, Mutex,
        mpsc::{SyncSender, sync_channel},
    },
    thread::JoinHandle,
};

use anyhow::Result;
use clap::Parser;

mod config;
mod inference;
mod os;
mod queue;
mod thread;

use config::{Args, Policy, Settings};
use inference::InferenceEngine;
use os::{ShmBuffer, ShmFrame, TrackingAllocator};
use queue::Queue;
use thread::{
    spawn_bridge_thread, spawn_fusion_thread, spawn_inference_thread,
};

#[global_allocator]
static GLOBAL: TrackingAllocator = TrackingAllocator;

/// Creates a bridge thread and an inference thread for a given shared memory
/// name, queue capacity, and backpressure policy.
///
/// * `stream_name` - The name of the stream to be used for shared memory and
///   telemetry.
/// * `stream_id` - The stream ID associated with the bridge thread.
/// * `queue_capacity` - The maximum number of frames that can be held in the
///   queue.
/// * `inference_sender` - A `SyncSender<ShmFrame>` used to send
///   processed frames to the fusion thread.
/// * `policy` - The backpressure policy to apply when the queue is full.
/// * `inference_window` - The number of frames to process in each inference
///   window.
/// * `frame_shape` - The shape of the frames being processed, suitable for
///   tensor.
/// * `item_size_bytes` - The size of each frame item in bytes (e.g., 1 byte for
///   u8, 4 bytes for f32).
///
/// Returns a tuple containing the `JoinHandle`s of the spawned bridge and
/// inference threads.
fn spawn_bridge_and_inference_threads(
    stream_name: &str,
    stream_id: usize,
    queue_capacity: usize,
    inference_sender: SyncSender<ShmFrame>,
    policy: Policy,
    inference_window: usize,
    frame_shape: Vec<i64>,
    item_size_bytes: usize,
) -> (JoinHandle<()>, JoinHandle<()>) {
    let queue = Arc::new(Mutex::new(Queue::<ShmFrame>::new(queue_capacity)));

    let bridge = spawn_bridge_thread(stream_name, stream_id, &queue, policy)
        .expect("Failed to spawn bridge thread");

    let inference = spawn_inference_thread(
        stream_name,
        &queue,
        inference_sender,
        format!("./models/{}_epctx.onnx", stream_name).as_str(),
        inference_window,
        frame_shape,
        item_size_bytes,
    )
    .expect("Failed to spawn inference thread");

    (bridge, inference)
}

fn main() -> Result<()> {
    ort::init().with_name("pipeline").commit();

    let args = Args::try_parse()?;

    if args.precompile {
        print!("Pre-compiling RGB model ...");
        let _ = InferenceEngine::try_new(
            "./models/RGB_epctx.onnx",
            vec![1, 3, 1080, 1920],
        )
        .expect("Failed to pre-compile RGB");
        println!(" done");

        print!("Pre-compiling Accelerometer model ...");
        let _ = InferenceEngine::try_new(
            "./models/Accelerometer_epctx.onnx",
            vec![1, 53, 3],
        )
        .expect("Failed to pre-compile Accelerometer");
        println!(" done");

        print!("Pre-compiling Gyroscope model ...");
        let _ = InferenceEngine::try_new(
            "./models/Gyroscope_epctx.onnx",
            vec![1, 66, 3],
        )
        .expect("Failed to pre-compile Gyroscope");
        println!(" done");

        return Ok(());
    }

    let settings = Settings::try_new(args)?;

    let configs = [
        (
            &settings.rgb_queue_config,
            ShmBuffer::RGB_STREAM_ID,
            settings.rgb_policy,
        ),
        (
            &settings.accel_queue_config,
            ShmBuffer::ACCEL_STREAM_ID,
            settings.accel_policy,
        ),
        (
            &settings.gyro_queue_config,
            ShmBuffer::GYRO_STREAM_ID,
            settings.gyro_policy,
        ),
    ];

    let min_fps = configs.iter().map(|(queue, _, _)| queue.fps).min().unwrap();

    let (inference_sender, fusion_receiver) =
        sync_channel::<ShmFrame>(configs.len());

    let mut handles: Vec<_> = configs
        .into_iter()
        .flat_map(|(queue, stream_id, policy)| {
            let (bridge, inference) = spawn_bridge_and_inference_threads(
                queue.name.as_str(),
                stream_id,
                queue.capacity_frames,
                inference_sender.clone(),
                policy,
                queue.fps / min_fps,
                queue.frame_shape.clone(),
                queue.item_size_bytes,
            );
            [bridge, inference]
        })
        .collect();

    let fusion_handle = spawn_fusion_thread(
        fusion_receiver,
        vec![
            settings.rgb_queue_config.name.clone(),
            settings.accel_queue_config.name.clone(),
            settings.gyro_queue_config.name.clone(),
        ],
    )?;

    handles.push(fusion_handle);

    for handle in handles {
        handle.join().unwrap();
    }

    Ok(())
}
