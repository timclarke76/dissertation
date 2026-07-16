from dataclasses import dataclass
import datetime as dt
from pathlib import Path
import sys
import threading
from typing import Final

from include.config import Args, EventQueueConfig, Policy, Settings
from include.os import ShmBuffer, make_channel, gc
import include.os.gc
from include.thread import (
    spawn_bridge_thread,
    spawn_fusion_thread,
    spawn_inference_thread,
)
from include import Queue

dir = str(Path(__file__).resolve().parent)

if dir not in sys.path:
    sys.path.append(dir)


@dataclass(frozen=True)
class StreamConfig:
    queue: EventQueueConfig
    stream_id: int
    policy: Policy
    duration: dt.timedelta


def create_bridge_and_inference_threads(
    stream_name: str,
    stream_id: int,
    queue_capacity: int,
    inference_sender: Sender,
    policy: Policy,
    inference_time: int,
    inference_window: int,
) -> tuple[threading.Thread, threading.Thread]:
    """Creates a bridge thread and an inference thread for a given shared memory
    name, queue capacity, and backpressure policy.

    Args:
        stream_name: The name of the stream to be used for shared memory and
        telemetry.
        stream_id: The stream ID associated with the bridge thread.
        queue_capacity: The maximum number of frames that can be held in the
        queue.
        inference_sender: A `SyncSender<ShmFrame>` used to send processed frames
        to the fusion thread.
        policy: The backpressure policy to apply when the queue is full.
        inference_time: The simulated time taken to process each frame in the
        inference thread.
        inference_window: The number of frames to process in each inference
        window.

    Returns:
        A tuple containing the spawned bridge and inference threads."""

    queue = Queue(queue_capacity)

    bridge = spawn_bridge_thread(stream_name, stream_id, queue, policy)
    inference = spawn_inference_thread(
        stream_name, queue, inference_sender, inference_time, inference_window
    )

    return bridge, inference


def main():
    SETTINGS: Final[Settings] = Settings(Args())

    CONFIGS: Final[list[StreamConfig]] = [
        StreamConfig(
            queue=SETTINGS.rgb_queue_config,
            stream_id=ShmBuffer.RGB_STREAM_ID,
            policy=SETTINGS.rgb_policy,
            duration=dt.timedelta(milliseconds=33),
        ),
        StreamConfig(
            queue=SETTINGS.accel_queue_config,
            stream_id=ShmBuffer.ACCEL_STREAM_ID,
            policy=SETTINGS.accel_policy,
            duration=dt.timedelta(microseconds=500),
        ),
        StreamConfig(
            queue=SETTINGS.gyro_queue_config,
            stream_id=ShmBuffer.GYRO_STREAM_ID,
            policy=SETTINGS.gyro_policy,
            duration=dt.timedelta(microseconds=400),
        ),
    ]

    MIN_FPS: Final[int] = min(cfg.queue.fps for cfg in CONFIGS)

    (inference_sender, fusion_receiver) = make_channel(len(CONFIGS))

    HANDLES: Final[list[Thread]] = [
        thread
        for cfg in CONFIGS
        for thread in create_bridge_and_inference_threads(
            cfg.queue.name,
            cfg.stream_id,
            cfg.queue.capacity_frames,
            inference_sender,
            cfg.policy,
            cfg.duration.total_seconds(),
            # FIXME: I think this is too big for every implementation
            int(cfg.queue.fps / MIN_FPS),
        )
    ]

    fusion_thread = spawn_fusion_thread(
        fusion_receiver, [cfg.queue.name for cfg in CONFIGS]
    )

    HANDLES.append(fusion_thread)

    for handle in HANDLES:
        handle.join()


if __name__ == "__main__":
    main()
