use std::{
    hint::spin_loop,
    sync::{Arc, Mutex, mpsc::SyncSender},
    thread::{self, JoinHandle},
};

use anyhow::{Context, Result};

use crate::{
    inference::InferenceEngine,
    os::{ShmBuffer, ShmFrame, now_nanos},
    queue::Queue,
};

/// Spawns a new thread that continuously processes frames from a shared memory
/// buffer and sends them to the next stage in the pipeline, running inference
/// using the specified ONNX model.
///
/// * `stream_name` - The name of the stream associated with this inference
///   thread.
/// * `queue` - A reference to the Queue from which frames will be popped for
///   processing.
/// * `sender` - A reference to the Sender used to send processed frames to the
///   next stage in the pipeline.
/// * `model_path` - The path to the ONNX model file used for inference.
/// * `window_frames` - The number of frames to process in each inference
///   window.
/// * `frame_shape` - The shape of the frames being processed, suitable for
///   tensor.
/// * `item_size_bytes` - The size of each frame item in bytes (e.g., 1 byte for
///   u8, 4 bytes for f32).
///
/// Returns a `Result` containing the `JoinHandle` of the spawned thread, or an
/// error if the thread could not be spawned.
pub fn spawn_inference_thread(
    stream_name: impl Into<String>,
    queue: &Arc<Mutex<Queue<ShmFrame>>>,
    sender: SyncSender<ShmFrame>,
    model_path: &str,
    window_frames: usize,
    frame_shape: Vec<i64>,
    item_size_bytes: usize,
) -> Result<JoinHandle<()>> {
    let stream_name = stream_name.into();
    let queue = Arc::clone(queue);
    let model_path = model_path.to_string();

    thread::Builder::new()
        .name(format!("inference_{}", stream_name))
        .spawn(move || {
            let window_size_items: usize =
                frame_shape.iter().map(|&s| s as usize).product();
            let frame_size_items = window_size_items / window_frames;

            let mut engine = InferenceEngine::try_new(&model_path, frame_shape)
                .expect("Failed to initialise InferenceEngine");

            let mut samples_collected = 0;

            loop {
                let (item, lapped_frames, dropped_frames) = {
                    let mut q = queue.lock().unwrap();
                    (q.pop(), q.lapped_frames, q.dropped_frames)
                };

                let t_pipeline_in = now_nanos().expect(
                    "Failed to get current time in \
                        nanoseconds for t_pipeline_in",
                );

                if let Some(mut frame) = item {
                    frame.lapped_frames = lapped_frames;
                    frame.dropped_frames = dropped_frames;

                    if frame.seq_num == u64::MAX {
                        // The generator stream has ended, so we send the final
                        // frame to the fusion thread and exit the loop.
                        sender.send(frame).expect(
                            "Failed to send exit signal frame to output queue",
                        );
                        break;
                    }

                    let item_offset = samples_collected * frame_size_items;

                    if item_size_bytes == 1 {
                        unsafe {
                            let src_slice = std::slice::from_raw_parts(
                                frame.payload_ptr.ptr,
                                frame_size_items,
                            );

                            let dest_slice = &mut engine.input_buffer_mut()
                                [item_offset..item_offset + frame_size_items];

                            for (d, s) in
                                dest_slice.iter_mut().zip(src_slice.iter())
                            {
                                *d = *s as f32;
                            }
                        }
                    } else {
                        unsafe {
                            let frame_size_bytes =
                                frame_size_items * std::mem::size_of::<f32>();

                            let dest_ptr = engine
                                .input_buffer_mut()
                                .as_mut_ptr()
                                .add(item_offset)
                                as *mut u8;

                            std::ptr::copy_nonoverlapping(
                                frame.payload_ptr.ptr,
                                dest_ptr,
                                frame_size_bytes,
                            );
                        }
                    }

                    samples_collected += 1;

                    if samples_collected >= window_frames {
                        frame.timestamps[ShmBuffer::PIPELINE_IN_TS] =
                            t_pipeline_in;

                        frame.inference_result =
                            engine.run().expect("Inference execution failed");

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
