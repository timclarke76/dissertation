use std::{
    hint::spin_loop,
    sync::{Arc, Mutex, mpsc::SyncSender},
    thread::{self, JoinHandle},
    time::Duration,
};

use anyhow::{Context, Result};

use crate::{
    os::now_nanos,
    os::{ShmBuffer, ShmFrame},
    queue::Queue,
};

/// Spawns a new thread that continuously processes frames from a shared memory
/// buffer and sends them to the next stage in the pipeline, simulating
/// inference processing time for each frame.
///
/// * `stream_name` - The name of the stream associated with this inference
///   thread.
/// * `queue` - A reference to the Queue from which frames will be popped for
///   processing.
/// * `sender` - A reference to the Sender used to send processed frames to the
///   next stage in the pipeline.
/// * `time` - The simulated time taken to process each frame.
/// * `window` - The number of frames to process in each inference window.
///
/// Returns a `Result` containing the `JoinHandle` of the spawned thread, or an
/// error if the thread could not be spawned.
pub fn spawn_inference_thread(
    stream_name: impl Into<String>,
    queue: &Arc<Mutex<Queue<ShmFrame>>>,
    sender: SyncSender<ShmFrame>,
    time: Duration,
    window: usize,
) -> Result<JoinHandle<()>> {
    let stream_name = stream_name.into();
    let queue = Arc::clone(queue);

    thread::Builder::new()
        .name(format!("inference_{}", stream_name))
        .spawn(move || {
            let mut samples_collected = 0;

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
                    if frame.seq_num == u64::MAX {
                        // The generator stream has ended, so we send the final
                        // frame to the fusion thread and exit the loop.
                        sender.send(frame).expect(
                            "Failed to send exit signal frame to output queue",
                        );
                        break;
                    }

                    samples_collected += 1;

                    if samples_collected >= window {
                        frame.timestamps[ShmBuffer::PIPELINE_IN_TS] =
                            t_pipeline_in;

                        std::thread::sleep(time); // Simulate inference

                        frame.timestamps[ShmBuffer::PIPELINE_OUT_TS] =
                            now_nanos().expect(
                                "Failed to get current time in \
                            nanoseconds for t_pipeline_out",
                            );

                        sender
                            .send(frame)
                            .expect("Failed to send frame to output queue");

                        samples_collected = 0;
                    }
                } else {
                    // Yield the thread to avoid busy waiting when the queue is
                    // empty.
                    spin_loop();
                }
            }
        })
        .with_context(|| {
            format!("Failed to spawn inference thread for '{stream_name}'")
        })
}
