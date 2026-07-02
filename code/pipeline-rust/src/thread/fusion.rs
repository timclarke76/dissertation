use std::{
    sync::mpsc::{Receiver, sync_channel},
    time::Duration,
};

use anyhow::{Context, Result};

use super::{TelemetryEpoch, TelemetryWriter, spawn_telemetry_thread};
use crate::os::{ShmBuffer, ShmFrame, now_nanos};

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

            // Required to save the latest accelerometer and gyrometer
            // timestamps for fusion telemetry.
            let mut latest_accelerometer_timestamps =
                [0; ShmBuffer::NUM_TIMESTAMPS];
            let mut latest_gyrometer_timestamps =
                [0; ShmBuffer::NUM_TIMESTAMPS];

            while let Ok(mut frame) = receiver.recv() {
                match frame.stream_id {
                    ShmBuffer::ACCEL_STREAM_ID => {
                        // Only the most recent accelerometer timestamps are
                        // needed for fusion, so we store them here.
                        latest_accelerometer_timestamps = frame.timestamps;
                    }

                    ShmBuffer::GYRO_STREAM_ID => {
                        // Only the most recent gyrometer timestamps are
                        // needed for fusion, so we store them here.
                        latest_gyrometer_timestamps = frame.timestamps;
                    }

                    ShmBuffer::RGB_STREAM_ID => {
                        frame.timestamps[ShmBuffer::FUSION_IN_TS] = now_nanos()
                            .expect(
                                "Failed to get current time for FUSION_IN_TS",
                            );

                        // Simulate fusion
                        std::thread::sleep(Duration::from_millis(5));

                        frame.timestamps[ShmBuffer::FUSION_OUT_TS] = now_nanos(
                        )
                        .expect("Failed to get current time for FUSION_OUT_TS");

                        // Record the RGB telemetry.
                        telemetry_writers[ShmBuffer::RGB_STREAM_ID]
                            .record(frame.timestamps)
                            .expect("Failed to record RGB telemetry");

                        // Copy the fusion timestamps and record the
                        // accelerometer telemetry.
                        latest_accelerometer_timestamps
                            [ShmBuffer::FUSION_IN_TS] =
                            frame.timestamps[ShmBuffer::FUSION_IN_TS];
                        latest_accelerometer_timestamps
                            [ShmBuffer::FUSION_OUT_TS] =
                            frame.timestamps[ShmBuffer::FUSION_OUT_TS];
                        telemetry_writers[ShmBuffer::ACCEL_STREAM_ID]
                            .record(latest_accelerometer_timestamps)
                            .expect("Failed to record accelerometer telemetry");

                        // Copy the fusion timestamps and record the gyrometer
                        // telemetry.
                        latest_gyrometer_timestamps[ShmBuffer::FUSION_IN_TS] =
                            frame.timestamps[ShmBuffer::FUSION_IN_TS];
                        latest_gyrometer_timestamps[ShmBuffer::FUSION_OUT_TS] =
                            frame.timestamps[ShmBuffer::FUSION_OUT_TS];
                        telemetry_writers[ShmBuffer::GYRO_STREAM_ID]
                            .record(latest_gyrometer_timestamps)
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
