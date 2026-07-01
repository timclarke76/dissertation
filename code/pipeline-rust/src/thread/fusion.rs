use std::{sync::mpsc::Receiver, time::Duration};

use anyhow::{Context, Result};

use super::spawn_telemetry_thread;

use crate::{os::now_nanos, shm::SharedMemoryBuffer, shm::SharedMemoryFrame};

/// Spawns a thread for late fusion of frames from a shared memory queue. Fusion
/// is only performed when an RGB frame is received, with the latest
/// accelerometer and gyrometer frames.
/// #Args
/// * `receiver` - A `Receiver<SharedMemoryFrame>` that receives frames to be
///   processed.
/// * `stream_names` - A vector of stream names to be used for telemetry and
///   thread identification. The first name in the vector is used for the RGB
///   stream, the second for the accelerometer stream, and the third for the
///   gyroscope stream.
/// #Returns
/// A `Result` containing the `JoinHandle` of the spawned thread, or an error if
/// the thread could not be spawned.
pub fn spawn_fusion_thread(
    receiver: Receiver<SharedMemoryFrame>,
    stream_names: Vec<String>,
) -> Result<std::thread::JoinHandle<()>> {
    std::thread::Builder::new()
        .name("fusion".to_string())
        .spawn(move || {
            let mut telemetry_writers: Vec<_> = stream_names
                .iter()
                .map(|name| {
                    spawn_telemetry_thread(name.as_str())
                        .expect("Failed to spawn telemetry thread")
                })
                .collect();

            // Required to save the latest accelerometer and gyrometer
            // timestamps for fusion telemetry.
            let mut latest_accelerometer_timestamps =
                [0; SharedMemoryBuffer::NUM_TIMESTAMPS];
            let mut latest_gyrometer_timestamps =
                [0; SharedMemoryBuffer::NUM_TIMESTAMPS];

            while let Ok(mut frame) = receiver.recv() {
                match frame.stream_id {
                    SharedMemoryBuffer::ACCELEROMETER_STREAM_ID => {
                        // Only the most recent accelerometer timestamps are
                        // needed for fusion, so we store them here.
                        latest_accelerometer_timestamps = frame.timestamps;
                    }

                    SharedMemoryBuffer::GYROSCOPE_STREAM_ID => {
                        // Only the most recent gyrometer timestamps are
                        // needed for fusion, so we store them here.
                        latest_gyrometer_timestamps = frame.timestamps;
                    }

                    SharedMemoryBuffer::RGB_STREAM_ID => {
                        frame.timestamps
                            [SharedMemoryBuffer::FUSION_IN_TIMESTAMP] =
                            now_nanos().expect(
                                "Failed to get current time for t_fusion_in",
                            );

                        // Simulate fusion
                        std::thread::sleep(Duration::from_millis(5));

                        frame.timestamps
                            [SharedMemoryBuffer::FUSION_OUT_TIMESTAMP] =
                            now_nanos().expect(
                                "Failed to get current time for t_fusion_out",
                            );

                        // Record the RGB telemetry.
                        telemetry_writers[0].record(frame.timestamps).unwrap();
                        telemetry_writers[SharedMemoryBuffer::RGB_STREAM_ID]
                            .record(frame.timestamps)
                            .expect("Failed to record RGB telemetry");

                        // Copy the fusion timestamps and record the
                        // accelerometer telemetry.
                        latest_accelerometer_timestamps
                            [SharedMemoryBuffer::FUSION_IN_TIMESTAMP] = frame
                            .timestamps
                            [SharedMemoryBuffer::FUSION_IN_TIMESTAMP];
                        latest_accelerometer_timestamps
                            [SharedMemoryBuffer::FUSION_OUT_TIMESTAMP] = frame
                            .timestamps
                            [SharedMemoryBuffer::FUSION_OUT_TIMESTAMP];
                        telemetry_writers
                            [SharedMemoryBuffer::ACCELEROMETER_STREAM_ID]
                            .record(latest_accelerometer_timestamps)
                            .expect("Failed to record accelerometer telemetry");

                        // Copy the fusion timestamps and record the gyrometer
                        // telemetry.
                        latest_gyrometer_timestamps
                            [SharedMemoryBuffer::FUSION_IN_TIMESTAMP] = frame
                            .timestamps
                            [SharedMemoryBuffer::FUSION_IN_TIMESTAMP];
                        latest_gyrometer_timestamps
                            [SharedMemoryBuffer::FUSION_OUT_TIMESTAMP] = frame
                            .timestamps
                            [SharedMemoryBuffer::FUSION_OUT_TIMESTAMP];
                        telemetry_writers
                            [SharedMemoryBuffer::GYROSCOPE_STREAM_ID]
                            .record(latest_gyrometer_timestamps)
                            .expect("Failed to record gyroscope telemetry");
                    }

                    _ => {
                        unreachable!("Unknown stream ID: {}", frame.stream_id);
                    }
                }
            }
        })
        .context("Failed to spawn fusion thread")
}
