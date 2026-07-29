use std::sync::mpsc::{Receiver, sync_channel};

use anyhow::{Context, Result};

use super::{TelemetryEpoch, TelemetryWriter, spawn_telemetry_thread};
use crate::{
    inference::InferenceEngine,
    os::{ShmBuffer, ShmFrame, now_nanos},
};

/// Spawns a thread for late fusion of frames from a shared memory queue. Fusion
/// is only performed when an RGB frame is received, with the latest
/// accelerometer and gyrometer frames.
///
/// * `receiver` - A reference to the `Receiver` used to receive frames from the
///   inference threads.
/// * `stream_names` - A vector of stream names to be used for telemetry and
///   thread identification. The first name in the vector is used for the RGB
///   stream, the second for the accelerometer stream, and the third for the
///   gyroscope stream.
///
/// Returns a `Result` containing the `JoinHandle` of the spawned thread, or an
/// error if the thread could not be spawned.
pub fn spawn_fusion_thread(
    receiver: Receiver<ShmFrame>,
    stream_names: Vec<String>,
) -> Result<std::thread::JoinHandle<()>> {
    std::thread::Builder::new()
        .name("fusion".to_string())
        .spawn(move || {
            let (telemetry_handles, mut telemetry_writers): (Vec<_>, Vec<_>) =
                stream_names
                    .iter()
                    .map(|name| {
                        let (telemetry_sender, inference_receiver) =
                            sync_channel::<TelemetryEpoch>(3);
                        let (inference_sender, telemetry_receiver) =
                            sync_channel::<TelemetryEpoch>(3);
                        (
                            spawn_telemetry_thread(
                                name.as_str(),
                                telemetry_sender,
                                telemetry_receiver,
                            )
                            .expect("Failed to spawn telemetry thread"),
                            TelemetryWriter::try_new(
                                inference_sender,
                                inference_receiver,
                            )
                            .expect("Failed to create telemetry writer"),
                        )
                    })
                    .unzip();

            let mut fusion_input = vec![0.0f32; 12];
            let mut engine = InferenceEngine::try_new(
                "./models/Fusion_epctx.onnx",
                vec![1, 12],
            )
            .expect("Failed to initialize fusion engine");

            // Required to save the latest accel and gyro
            // timestamps for fusion telemetry.
            let mut latest_accel_timestamps = [0; ShmBuffer::NUM_TIMESTAMPS];
            let mut latest_accel_lapped_frames = 0;
            let mut latest_accel_dropped_frames = 0;
            let mut latest_accel_result = [0.0f32; 4];

            let mut latest_gyro_timestamps = [0; ShmBuffer::NUM_TIMESTAMPS];
            let mut latest_gyro_lapped_frames = 0;
            let mut latest_gyro_dropped_frames = 0;
            let mut latest_gyro_result = [0.0f32; 4];

            let mut eos_count = 0;

            while let Ok(mut frame) = receiver.recv() {
                if frame.seq_num == u64::MAX {
                    // A generator stream has ended. Terminate the corresponding
                    // telemetry writer and increment the end-of-stream count.
                    // If all streams have ended, exit the loop.

                    telemetry_writers[frame.stream_id]
                        .terminate()
                        .expect("Failed to terminate telemetry writer");

                    eos_count += 1;

                    if eos_count == ShmBuffer::NUM_STREAMS {
                        break;
                    }

                    // Wait for all streams to end before exiting the loop.
                    // Don't process the EOS frame.
                    continue;
                }

                match frame.stream_id {
                    ShmBuffer::ACCEL_STREAM_ID => {
                        // Only the most recent accelerometer timestamps are
                        // needed for fusion, so we store them here.
                        latest_accel_timestamps = frame.timestamps;
                        latest_accel_lapped_frames = frame.lapped_frames;
                        latest_accel_dropped_frames = frame.dropped_frames;
                        latest_accel_result = frame.inference_result;
                    }

                    ShmBuffer::GYRO_STREAM_ID => {
                        // Only the most recent gyro timestamps are
                        // needed for fusion, so we store them here.
                        latest_gyro_timestamps = frame.timestamps;
                        latest_gyro_lapped_frames = frame.lapped_frames;
                        latest_gyro_dropped_frames = frame.dropped_frames;
                        latest_gyro_result = frame.inference_result;
                    }

                    ShmBuffer::RGB_STREAM_ID => {
                        // Do not fuse or record telemetry until all streams
                        // have provided at least one valid frame for ZoH.
                        if latest_accel_timestamps[ShmBuffer::GENERATED_TS] == 0
                            || latest_gyro_timestamps[ShmBuffer::GENERATED_TS]
                                == 0
                        {
                            continue;
                        }

                        frame.timestamps[ShmBuffer::FUSION_IN_TS] = now_nanos()
                            .expect(
                                "Failed to get current time for FUSION_IN_TS",
                            );

                        fusion_input[0..4]
                            .copy_from_slice(&frame.inference_result);
                        fusion_input[4..8]
                            .copy_from_slice(&latest_accel_result);
                        fusion_input[8..12]
                            .copy_from_slice(&latest_gyro_result);
                        let _ = engine
                            .run(&fusion_input)
                            .expect("Fusion inference failed");

                        frame.timestamps[ShmBuffer::FUSION_OUT_TS] = now_nanos(
                        )
                        .expect("Failed to get current time for FUSION_OUT_TS");

                        // Record the RGB telemetry.
                        telemetry_writers[ShmBuffer::RGB_STREAM_ID]
                            .record(
                                frame.timestamps,
                                frame.lapped_frames,
                                frame.dropped_frames,
                            )
                            .expect("Failed to record RGB telemetry");

                        // Copy the fusion timestamps and record the
                        // accelerometer telemetry.
                        latest_accel_timestamps[ShmBuffer::FUSION_IN_TS] =
                            frame.timestamps[ShmBuffer::FUSION_IN_TS];
                        latest_accel_timestamps[ShmBuffer::FUSION_OUT_TS] =
                            frame.timestamps[ShmBuffer::FUSION_OUT_TS];
                        telemetry_writers[ShmBuffer::ACCEL_STREAM_ID]
                            .record(
                                latest_accel_timestamps,
                                latest_accel_lapped_frames,
                                latest_accel_dropped_frames,
                            )
                            .expect("Failed to record accelerometer telemetry");

                        // Copy the fusion timestamps and record the gyrometer
                        // telemetry.
                        latest_gyro_timestamps[ShmBuffer::FUSION_IN_TS] =
                            frame.timestamps[ShmBuffer::FUSION_IN_TS];
                        latest_gyro_timestamps[ShmBuffer::FUSION_OUT_TS] =
                            frame.timestamps[ShmBuffer::FUSION_OUT_TS];
                        telemetry_writers[ShmBuffer::GYRO_STREAM_ID]
                            .record(
                                latest_gyro_timestamps,
                                latest_gyro_lapped_frames,
                                latest_gyro_dropped_frames,
                            )
                            .expect("Failed to record gyroscope telemetry");
                    }

                    _ => {
                        unreachable!("Unknown stream ID: {}", frame.stream_id);
                    }
                }
            }

            for handle in telemetry_handles {
                handle.join().unwrap();
            }
        })
        .context("Failed to spawn fusion thread")
}
