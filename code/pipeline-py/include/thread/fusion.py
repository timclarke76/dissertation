import threading
import time

import numpy as np

from include.inference import InferenceEngine
from include.os import make_channel, Receiver, ShmBuffer
from .telemetry import TelemetryWriter, spawn_telemetry_thread


def spawn_fusion_thread(
    receiver: Receiver,
    stream_names: list[str],
) -> threading.Thread:
    def fusion_thread():
        telemetry_threads: list[TelemetryWriter] = []
        telemetry_writers: list[TelemetryWriter] = []

        for name in stream_names:
            (telemetry_sender, inference_reciever) = make_channel(3)
            (inference_sender, telemetry_reciever) = make_channel(3)

            try:
                telemetry_threads.append(
                    spawn_telemetry_thread(
                        name, telemetry_sender, telemetry_reciever
                    ),
                )
            except Exception as e:
                raise RuntimeError(
                    f"Failed to spawn telemetry thread for stream {name}"
                ) from e

            try:
                telemetry_writers.append(
                    TelemetryWriter(inference_sender, inference_reciever)
                )
            except Exception as e:
                raise RuntimeError(
                    f"Failed to create telemetry writer for stream {name}"
                ) from e

        fusion_input = np.zeros((1, 12), dtype=np.float32)
        engine = InferenceEngine("./models/Fusion_epctx.onnx", fusion_input)

        """Required to save the latest accelerometer and gyrometer
        timestamps for fusion telemetry."""
        latest_accel_ts: list[int] = [
            0 for _ in range(ShmBuffer.NUM_TIMESTAMPS)
        ]
        latest_accel_lapped_frames: int = 0
        latest_accel_dropped_frames: int = 0

        latest_gyro_ts: list[int] = [0 for _ in range(ShmBuffer.NUM_TIMESTAMPS)]
        latest_gyro_lapped_frames: int = 0
        latest_gyro_dropped_frames: int = 0

        eos_count = 0

        while True:
            frame = receiver.receive()

            if frame.seq_num == ShmBuffer.POISON_PILL:
                """A generator stream has ended. Terminate the corresponding
                telemetry writer and increment the end-of-stream count. If all
                streams have ended, exit the loop."""

                try:
                    telemetry_writers[frame.stream_id].terminate()
                except Exception as e:
                    raise RuntimeError(
                        "Failed to terminate telemetry writer "
                        f"for stream {frame.stream_id}"
                    ) from e

                eos_count += 1

                if eos_count == ShmBuffer.NUM_STREAMS:
                    break

                continue

            if frame.stream_id == ShmBuffer.ACCEL_STREAM_ID:
                """Only the most recent accelerometer timestamps are needed for
                fusion, so we store them here."""
                latest_accel_ts = frame.timestamps.copy()
                latest_accel_lapped_frames = frame.lapped_frames
                latest_accel_dropped_frames = frame.dropped_frames
                fusion_input[0, 4:8] = frame.inference_result
            elif frame.stream_id == ShmBuffer.GYRO_STREAM_ID:
                """Only the most recent gyro timestamps are needed for
                fusion, so we store them here."""
                latest_gyro_ts = frame.timestamps.copy()
                latest_gyro_lapped_frames = frame.lapped_frames
                latest_gyro_dropped_frames = frame.dropped_frames
                fusion_input[0, 8:12] = frame.inference_result
            elif frame.stream_id == ShmBuffer.RGB_STREAM_ID:
                # Do not fuse or record telemetry until all streams have
                # provided at least one valid frame for ZoH.
                if (
                    latest_accel_ts[ShmBuffer.GENERATED_TS] == 0
                    or latest_gyro_ts[ShmBuffer.GENERATED_TS] == 0
                ):
                    continue

                frame.timestamps[ShmBuffer.FUSION_IN_TS] = (
                    time.perf_counter_ns()
                )

                fusion_input[0, 0:4] = frame.inference_result
                engine.run()

                frame.timestamps[ShmBuffer.FUSION_OUT_TS] = (
                    time.perf_counter_ns()
                )

                try:
                    # Record the RGB telemetry.
                    telemetry_writers[ShmBuffer.RGB_STREAM_ID].record(
                        frame.timestamps,
                        frame.lapped_frames,
                        frame.dropped_frames,
                    )
                except Exception as e:
                    raise RuntimeError("Failed to record RGB telemetry") from e

                latest_accel_ts[ShmBuffer.FUSION_IN_TS] = frame.timestamps[
                    ShmBuffer.FUSION_IN_TS
                ]
                latest_accel_ts[ShmBuffer.FUSION_OUT_TS] = frame.timestamps[
                    ShmBuffer.FUSION_OUT_TS
                ]

                try:
                    # Copy the fusion timestamps and record the accelerometer
                    # telemetry.
                    telemetry_writers[ShmBuffer.ACCEL_STREAM_ID].record(
                        latest_accel_ts,
                        latest_accel_lapped_frames,
                        latest_accel_dropped_frames,
                    )
                except Exception as e:
                    raise RuntimeError(
                        "Failed to record accelerometer telemetry"
                    ) from e

                latest_gyro_ts[ShmBuffer.FUSION_IN_TS] = frame.timestamps[
                    ShmBuffer.FUSION_IN_TS
                ]
                latest_gyro_ts[ShmBuffer.FUSION_OUT_TS] = frame.timestamps[
                    ShmBuffer.FUSION_OUT_TS
                ]

                try:
                    # Copy the fusion timestamps and record the gyrometer
                    # telemetry.
                    telemetry_writers[ShmBuffer.GYRO_STREAM_ID].record(
                        latest_gyro_ts,
                        latest_gyro_lapped_frames,
                        latest_gyro_dropped_frames,
                    )
                except Exception as e:
                    raise RuntimeError(
                        "Failed to record gyrometer telemetry"
                    ) from e
            else:
                raise ValueError(f"Unknown stream ID: {frame.stream_id}")

        for thread in telemetry_threads:
            thread.join()

    try:
        thread = threading.Thread(
            target=fusion_thread, name='fusion', daemon=True
        )
        thread.start()
    except Exception as e:
        raise RuntimeError(
            f"Failed to spawn fusion thread for '{shm_name}'"
        ) from e

    return thread
