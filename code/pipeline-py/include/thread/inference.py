import threading
import time

from include.os import Sender, ShmBuffer
from include.queue import Queue


def spawn_inference_thread(
    stream_name: str,
    queue: Queue,
    sender: Sender,
    inference_time: int,
    window: int,
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
        window: The number of frames to process in each inference window.

    Returns:
        The spawned thread."""

    def inference_thread():
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

                samples_collected += 1

                if samples_collected >= window:
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
