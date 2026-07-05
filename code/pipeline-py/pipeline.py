from dataclasses import dataclass
import datetime as dt
from typing import Final

from config import Args, Policy, QueueConfig, Settings
from os_ import ShmBuffer


@dataclass(frozen=True)
class StreamConfig:
    queue: QueueConfig
    stream_id: int
    policy: Policy
    duration: dt.timedelta


def main():
    SETTINGS: Final[Settings] = Settings(Args())

    CONFIGS: Final[list[StreamConfig]] = [
        StreamConfig(
            queue=SETTINGS.rgb_queue,
            stream_id=ShmBuffer.RGB_STREAM_ID,
            policy=SETTINGS.rgb_policy,
            duration=dt.timedelta(milliseconds=33),
        ),
        StreamConfig(
            queue=SETTINGS.accelerometer_queue,
            stream_id=ShmBuffer.ACCEL_STREAM_ID,
            policy=SETTINGS.accelerometer_policy,
            duration=dt.timedelta(microseconds=500),
        ),
        StreamConfig(
            queue=SETTINGS.gyroscope_queue,
            stream_id=ShmBuffer.GYRO_STREAM_ID,
            policy=SETTINGS.gyroscope_policy,
            duration=dt.timedelta(microseconds=400),
        ),
    ]

    CHANNEL_SIZE: Final[int] = sum(cfg.queue.capacity_frames for cfg in CONFIGS)
    MIN_FPS: Final[int] = min(cfg.queue.fps for cfg in CONFIGS)
    BUFFERS: Final[list[ShmBuffer]] = [
        ShmBuffer(cfg.queue.name, cfg.stream_id) for cfg in CONFIGS
    ]

    shm_buffer = BUFFERS[0]
    while True:
        frame = shm_buffer.next_frame()
        print(
            f"Stream ID: {frame.stream_id}, "
            f"Sequence Number: {frame.seq_num}, "
            f"Timestamps: {frame.timestamps}"
        )
        if frame.seq_num == ShmBuffer.POISON_PILL:
            print("Received poison pill. Exiting.")
            break


if __name__ == "__main__":
    main()
