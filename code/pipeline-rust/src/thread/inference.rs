use std::{
    hint::spin_loop,
    sync::{Arc, Mutex, mpsc::SyncSender},
    thread::{self, JoinHandle},
    time::{Duration, Instant},
};

use anyhow::{Context, Result};

use crate::{
    os::now_nanos,
    os::{ShmBuffer, ShmFrame},
    queue::Queue,
};

/// Spawns a thread that simulates inference processing on frames from a shared
/// memory queue. The thread will process frames at a specified inference time
/// and record latency telemetry for each processed frame. The thread will
/// exit after 10 seconds of processing, printing a summary of processed and
/// dropped frames, as well as the current queue depth.
/// #Args
/// * `stream_name` - The name of the stream to be used for telemetry and thread
///   identification.
/// * `queue` - An `Arc<Mutex<Queue<ShmFrame>>>` that holds the frames
///   to be processed.
/// * `sender` - A `SyncSender<ShmFrame>` used to send processed frames
///   to the next stage in the pipeline.
/// * `inference_time` - The duration to simulate inference processing for each
///   frame.
/// #Returns
/// A `Result` containing the `JoinHandle` of the spawned thread, or an error if
/// the thread could not be spawned.
pub fn spawn_inference_thread<S: AsRef<str>>(
    stream_name: S,
    queue: &Arc<Mutex<Queue<ShmFrame>>>,
    sender: SyncSender<ShmFrame>,
    inference_time: Duration,
) -> Result<JoinHandle<()>> {
    let thread_stream_name = stream_name.as_ref().to_string();
    let queue = Arc::clone(queue);

    thread::Builder::new()
        .name(format!("inference_{}", thread_stream_name))
        .spawn(move || {
            let start_time = Instant::now();

            loop {
                let item = {
                    let mut q = queue.lock().unwrap();
                    q.pop()
                };

                let t_pipeline_in = now_nanos().expect(
                    "Failed to get current time in \
                        nanoseconds for t_pipeline_in",
                );

                if let Some(mut frame) = item {
                    frame.timestamps[ShmBuffer::PIPELINE_IN_TS] = t_pipeline_in;

                    std::thread::sleep(inference_time); // Simulate inference

                    frame.timestamps[ShmBuffer::PIPELINE_OUT_TS] = now_nanos()
                        .expect(
                            "Failed to get current time in \
                            nanoseconds for t_pipeline_out",
                        );

                    sender
                        .send(frame)
                        .expect("Failed to send frame to output queue");
                } else {
                    // Yield the thread to avoid busy waiting when the queue is
                    // empty.
                    spin_loop();
                }

                if start_time.elapsed() > Duration::from_secs(10) {
                    println!("Benchmark complete. Exiting.");
                    std::process::exit(0);
                }
            }
        })
        .with_context(|| {
            let stream_name = stream_name.as_ref().to_string();
            format!("Failed to spawn inference thread for '{stream_name}'")
        })
}
