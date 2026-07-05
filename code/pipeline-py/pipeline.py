from dataclasses import dataclass
import datetime as dt
from typing import Final

from config import Args, Policy, QueueConfig, Settings


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
            stream_id=0,
            policy=SETTINGS.rgb_policy,
            duration=dt.timedelta(milliseconds=33),
        ),
        StreamConfig(
            queue=SETTINGS.accelerometer_queue,
            stream_id=1,
            policy=SETTINGS.accelerometer_policy,
            duration=dt.timedelta(microseconds=500),
        ),
        StreamConfig(
            queue=SETTINGS.gyroscope_queue,
            stream_id=2,
            policy=SETTINGS.gyroscope_policy,
            duration=dt.timedelta(microseconds=400),
        ),
    ]

    CHANNEL_SIZE: Final[int] = sum(cfg.queue.capacity_frames for cfg in CONFIGS)
    MIN_FPS: Final[int] = min(cfg.queue.fps for cfg in CONFIGS)


if __name__ == "__main__":
    main()
