import threading
import time

import ctypes
from multiprocessing import shared_memory
from multiprocessing.resource_tracker import unregister
import numpy as np

from include.os import Sender, ShmBuffer
from include.queue import Queue


def spawn_inference_thread(
    stream_name: str,
    queue: Queue,
    sender: Sender,
    inference_time: int,
    window_frames: int,
    frame_shape: list[int],
    item_size_bytes: int,
) -> threading.Thread:
    """Spawns a new thread that continuously processes frames from a shared
    memory buffer and sends them to the next stage in the pipeline, simulating
    inference processing time for each frame.

    Args:
        stream_name: The name of the stream associated with this inference
        thread.
        queue: A reference to the Queue from which frames will be popped for
        processing.
        sender: A reference to the Sender used to send processed frames to the
        next stage in the pipeline.
        inference_time: The simulated time taken to process each frame.
        window_frames: The number of frames to process in each inference window.
        frame_shape: The shape of the frames being processed, suitable for
        tensor.
        item_size_bytes: The size of each frame item in bytes (e.g. 1 byte for
        uint8, 4 bytes for float32).

    Returns:
        The spawned thread."""

    def inference_thread():
        window_size_items = int(np.prod(frame_shape))
        window_size_bytes = window_size_items * item_size_bytes
        frame_size_bytes = window_size_bytes // window_frames

        shm = shared_memory.SharedMemory(name=stream_name)
        unregister(shm._name, 'shared_memory')
        shm_ptr = ctypes.addressof(ctypes.c_char.from_buffer(shm.buf))

        tensor_data = (ctypes.c_uint8 * window_size_bytes)()
        tensor_ptr = ctypes.addressof(tensor_data)

        samples_collected = 0

        while True:
            with queue.lock:
                frame = queue.pop()
                lapped_frames = queue.lapped_frames
                dropped_frames = queue.dropped_frames

            t_pipeline_in = time.perf_counter_ns()

            if frame != None:
                frame.lapped_frames = lapped_frames
                frame.dropped_frames = dropped_frames

                if frame.seq_num == ShmBuffer.POISON_PILL:
                    # The generator stream has ended, so we send the final
                    # frame to the fusion thread and exit the loop.
                    try:
                        sender.send(frame)
                    except Exception as e:
                        e.add_note(
                            "Failed to send exit signal frame to output queue"
                        )
                    break

                src_ptr = int(shm_ptr + frame.payload_offset)
                dst_ptr = int(
                    tensor_ptr + (samples_collected * frame_size_bytes)
                )
                ctypes.memmove(dst_ptr, src_ptr, frame_size_bytes)

                samples_collected += 1

                if samples_collected >= window_frames:
                    frame.timestamps[ShmBuffer.PIPELINE_IN_TS] = t_pipeline_in

                    time.sleep(
                        inference_time / 1_000_000_000
                    )  # Simulate inference

                    frame.timestamps[ShmBuffer.PIPELINE_OUT_TS] = (
                        time.perf_counter_ns()
                    )

                    try:
                        sender.send(frame)
                    except Exception as e:
                        e.add_note("Failed to send frame to output queue")
                        raise

                    samples_collected = 0
            else:
                pass

    try:
        thread = threading.Thread(
            target=inference_thread,
            name=f"inference_{stream_name}",
            daemon=True,
        )
        thread.start()
    except Exception as e:
        e.add_note(f"Failed to spawn inference thread for '{shm_name}': {e}")
        raise

    return thread
