from dataclasses import dataclass
import datetime as dt
from pathlib import Path
import sys
import threading
from typing import Final

from include.config import Args, Policy, QueueConfig, Settings
from include.os import ShmBuffer, make_channel
from include.thread import spawn_bridge_thread
from include import Queue

dir = str(Path(__file__).resolve().parent)

if dir not in sys.path:
    sys.path.append(dir)


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
    (inference_sender, fusion_receiver) = make_channel(CHANNEL_SIZE)

    HANDLES: Final[list[Thread]] = [
        spawn_bridge_thread(
            cfg.queue.name,
            cfg.stream_id,
            Queue(cfg.queue.capacity_frames),
            cfg.policy,
        )
        for cfg in CONFIGS
    ]

    [handle.join() for handle in HANDLES]


if __name__ == "__main__":
    main()
