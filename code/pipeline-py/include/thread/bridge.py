import threading
import time

from include.queue import Queue
from include.os import ShmBuffer, saturating_sub
from include.config import Policy
from include.config import *


def spawn_bridge_thread(
    shm_name: str, stream_id: int, queue: Queue, policy: Policy
) -> threading.Thread:
    """Spawns a new thread that continuously reads frames from a shared memory
    buffer and pushes them into a queue, applying the specified backpressure
    policy when the queue is full.

    Args:
        shm_name: The name of the shared memory buffer to read from.
        stream_id: The stream ID associated with this bridge.
        queue: A reference to the `Queue` where frames will be pushed.
        policy: The backpressure `Policy` to apply when the queue is full.

    Returns:
        The spawned thread"""

    def bridge_thread():
        try:
            shm_buffer = ShmBuffer(shm_name, stream_id)
        except Exception as e:
            e.add_note(f"Failed to connect to '{shm_name}': {e}")
            raise

        decimation_counter: int = 0

        while True:
            try:
                frame = shm_buffer.next_frame()
            except Exception as e:
                e.add_note(f"Failed to read next frame from shared memory: {e}")
                raise

            with queue.lock:
                queue.lapped_frames += frame.lapped_frames

            if frame.seq_num == ShmBuffer.POISON_PILL:
                with queue.lock:
                    # The generator stream has ended, so push the final
                    # frame to the queue and exit the loop.
                    if not queue.try_push(frame):
                        queue.overwrite_oldest(frame)

                break

            if isinstance(policy, AdaptiveDecimation):
                # Dynamically downsamples the data stream (i.e. queueing only
                # every nth event) to reduce pressure on the consumer buffer
                # while preserving the temporal continuity of the data.

                # When using Adaptive Decimation, and the queue's length is
                # above a given threshold, only every nth frame is queued and
                # the remained are discarded _before_ attempting to push to the
                # queue. N is calculated based on how deep into the "danger
                # zone" (the region between the threshold and the queue's
                # capacity) we are, and scaled between a minimum and maximum
                # ratio.

                with queue.lock:
                    if queue.len >= policy.threshold:
                        # Determine how deep into the danger zone we are, and
                        # scale the decimation ratio accordingly.
                        # `saturating_sub` avoids underflow and wraparound.
                        zone_size = saturating_sub(
                            queue.capacity, policy.threshold
                        )
                        depth = saturating_sub(queue.len, policy.threshold)

                        # Calculate a decimation ratio scaled between min_ratio
                        # and max_ratio based on how deep into the danger zone
                        # that we are. The deeper we are, the closer we get to
                        # max_ratio. If we are at the threshold, we use
                        # min_ratio.
                        if zone_size > 0:
                            numerator = depth * (
                                policy.max_ratio - policy.min_ratio
                            )
                            ratio = policy.min_ratio + (numerator // zone_size)
                        else:
                            # Threshold is at or above capacity, so we use the
                            # maximum ratio.
                            ratio = policy.max_ratio

                        decimation_counter += 1

                        if decimation_counter % ratio != 0:
                            queue.dropped_frames += 1
                            continue  # drop
                        else:
                            # reset
                            decimation_counter = 0

            if not queue.try_push(frame):
                match policy:
                    case BoundedQueue():
                        # Blocks the producer until space is available in the
                        # consumer buffer.
                        while True:
                            with queue.lock:
                                if queue.try_push(frame):
                                    break

                    case ExponentialBackoff():
                        # Waits a short time before retrying to insert the data,
                        # with the wait time multiplied with each retry.
                        backoff_nanos = policy.base_nanos

                        while True:
                            time.sleep(backoff_nanos / 1_000_000_000)

                            with queue.lock:
                                if queue.try_push(frame):
                                    break

                            backoff_nanos *= policy.multiplier

                            if backoff_nanos > policy.max_nanos:
                                with queue.lock:
                                    # drop
                                    queue.dropped_frames += 1
                                    break

                    case DropOldest():
                        # Drops the oldest data in the consumer buffer to make
                        # room for new data.
                        with queue.lock:
                            queue.overwrite_oldest(frame)
                            queue.dropped_frames += 1

                    case DropNewest():
                        # DropNewest drops incoming data when the buffer is
                        # full.
                        with queue.lock:
                            queue.dropped_frames += 1

                    case AdaptiveDecimation():
                        # If the Adaptive Decimation throttling is not enough to
                        # keep the queue from filling up, we drop the incoming
                        # frame.
                        with queue.lock:
                            queue.dropped_frames += 1

        shm_buffer.close()

    try:
        thread = threading.Thread(
            target=bridge_thread, name=f"bridge_{shm_name}", daemon=True
        )
        thread.start()
    except Exception as e:
        e.add_note(f"Failed to spawn bridge thread for '{shm_name}': {e}")
        raise

    return thread
