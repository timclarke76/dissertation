use std::{
    hint::spin_loop,
    sync::{Arc, Mutex},
    thread::{self, JoinHandle},
    time::{Duration, Instant},
};

use anyhow::{Context, Result};

use super::telemetry::spawn_telemetry_thread;
use crate::{os::now_nanos, queue::Queue, shm::SharedMemoryFrame};

/// Spawns a thread that simulates inference processing on frames from a shared
/// memory queue. The thread will process frames at a specified inference time
/// and record latency telemetry for each processed frame. The thread will
/// exit after 10 seconds of processing, printing a summary of processed and
/// dropped frames, as well as the current queue depth.
/// #Args
/// * `stream_name` - The name of the stream to be used for telemetry and thread
///   identification.
/// * `queue` - An `Arc<Mutex<Queue<SharedMemoryFrame>>>` that holds the frames
///   to be processed.
/// * `inference_time` - The duration to simulate inference processing for each
///   frame.
/// #Returns
/// A `Result` containing the `JoinHandle` of the spawned thread, or an error if
/// the thread could not be spawned.
pub fn spawn_inference_thread<S: AsRef<str>>(
    stream_name: S,
    queue: &Arc<Mutex<Queue<SharedMemoryFrame>>>,
    inference_time: Duration,
) -> Result<JoinHandle<()>> {
    let thread_stream_name = stream_name.as_ref().to_string();
    let queue = Arc::clone(queue);

    thread::Builder::new()
        .name(format!("inference_{}", thread_stream_name))
        .spawn(move || {
            let mut telemetry = spawn_telemetry_thread(thread_stream_name)
                .expect("Failed to spawn telemetry thread");
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
                    frame.timestamps[2] = t_pipeline_in;
                    frame.timestamps[3] = now_nanos().expect(
                        "Failed to get current time in \
                            nanoseconds for t_pipeline_out",
                    );
                    std::thread::sleep(inference_time); // Simulate inference
                    frame.timestamps[4] = now_nanos().expect(
                        "Failed to get current time in \
                            nanoseconds for t_fusion_in",
                    );
                    frame.timestamps[5] = now_nanos().expect(
                        "Failed to get current time in \
                            nanoseconds for t_fusion_out",
                    );

                    telemetry
                        .record(frame.timestamps)
                        .expect("Failed to record telemetry");
                } else {
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
