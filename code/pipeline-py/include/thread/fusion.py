import threading
import time

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
                e.add_note(
                    f"Failed to spawn telemetry thread for stream {name}: {e}"
                )
                raise

            try:
                telemetry_writers.append(
                    TelemetryWriter(inference_sender, inference_reciever)
                )
            except Exception as e:
                e.add_note(
                    f"Failed to create telemetry writer for stream {name}: {e}"
                )
                raise

        """Required to save the latest accelerometer and gyrometer
        timestamps for fusion telemetry."""
        latest_accelerometer_timestamps: list[int] = [
            0 for _ in range(ShmBuffer.NUM_TIMESTAMPS)
        ]
        latest_accelerometer_lapped_frames: int = 0
        latest_accelerometer_dropped_frames: int = 0
        latest_gyrometer_timestamps: list[int] = [
            0 for _ in range(ShmBuffer.NUM_TIMESTAMPS)
        ]
        latest_gyrometer_lapped_frames: int = 0
        latest_gyrometer_dropped_frames: int = 0

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
                    e.add_note(
                        "Failed to terminate telemetry writer "
                        f"for stream {frame.stream_id}: {e}"
                    )
                    raise

                eos_count += 1

                if eos_count == ShmBuffer.NUM_STREAMS:
                    break

                continue

            if frame.stream_id == ShmBuffer.ACCEL_STREAM_ID:
                """Only the most recent accelerometer timestamps are needed for
                fusion, so we store them here."""
                latest_accelerometer_timestamps = frame.timestamps.copy()
                latest_accelerometer_lapped_frames = frame.lapped_frames
                latest_accelerometer_dropped_frames = frame.dropped_frames
            elif frame.stream_id == ShmBuffer.GYRO_STREAM_ID:
                """Only the most recent gyrometer timestamps are needed for
                fusion, so we store them here."""
                latest_gyrometer_timestamps = frame.timestamps.copy()
                latest_gyrometer_lapped_frames = frame.lapped_frames
                latest_gyrometer_dropped_frames = frame.dropped_frames
            elif frame.stream_id == ShmBuffer.RGB_STREAM_ID:
                frame.timestamps[ShmBuffer.FUSION_IN_TS] = (
                    time.perf_counter_ns()
                )
                time.sleep(0.005)  # Simulate fusion
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
                    e.add_note("Failed to record RGB telemetry: {e}")
                    raise

                latest_accelerometer_timestamps[ShmBuffer.FUSION_IN_TS] = (
                    frame.timestamps[ShmBuffer.FUSION_IN_TS]
                )
                latest_accelerometer_timestamps[ShmBuffer.FUSION_OUT_TS] = (
                    frame.timestamps[ShmBuffer.FUSION_OUT_TS]
                )

                try:
                    # Copy the fusion timestamps and record the accelerometer
                    # telemetry.
                    telemetry_writers[ShmBuffer.ACCEL_STREAM_ID].record(
                        latest_accelerometer_timestamps,
                        latest_accelerometer_lapped_frames,
                        latest_accelerometer_dropped_frames,
                    )
                except Exception as e:
                    e.add_note("Failed to record accelerometer telemetry: {e}")
                    raise

                latest_gyrometer_timestamps[ShmBuffer.FUSION_IN_TS] = (
                    frame.timestamps[ShmBuffer.FUSION_IN_TS]
                )
                latest_gyrometer_timestamps[ShmBuffer.FUSION_OUT_TS] = (
                    frame.timestamps[ShmBuffer.FUSION_OUT_TS]
                )

                try:
                    # Copy the fusion timestamps and record the gyrometer
                    # telemetry.
                    telemetry_writers[ShmBuffer.GYRO_STREAM_ID].record(
                        latest_gyrometer_timestamps,
                        latest_gyrometer_lapped_frames,
                        latest_gyrometer_dropped_frames,
                    )
                except Exception as e:
                    e.add_note("Failed to record gyrometer telemetry: {e}")
                    raise
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
        e.add_note(f"Failed to spawn fusion thread for '{shm_name}': {e}")
        raise

    return thread
