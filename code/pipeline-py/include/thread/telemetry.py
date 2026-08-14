import csv
from dataclasses import dataclass
import resource
import sys
import threading
import time
from typing import Final

from hdrh.histogram import HdrHistogram

from include.os import Sender, Receiver, saturating_sub
import include.os.gc as gc


class TelemetryEpoch:
    """A telemetry epoch that contains six HdrHistogram instances for recording
    latency measurements in nanoseconds. Each histogram tracks latency for a
    specific stage of the inference pipeline, as well as the total latency."""

    UNBOUNDED_QUEUE_WAIT: int = 0
    """The index of the histogram for unbounded queue wait latency."""

    IDIOMATIC_QUEUE_WAIT: int = 1
    """The index of the histogram for idiomatic queue wait latency."""

    INFERENCE_EXEC: int = 2
    """The index of the histogram for inference latency."""

    MPSC_WAIT: int = 3
    """The index of the histogram for multi-producer single-consumer (MPSC)
    queue wait latency."""

    FUSION_EXEC: int = 4
    """The index of the histogram for fusion latency."""

    TOTAL_LATENCY: int = 5
    """The index of the histogram for total latency."""

    NUM_LATENCY_MEASURES: int = 6
    """The number of latency measures tracked in an epoch."""

    latency_nanos: list[HdrHistogram]
    """The histograms for recording latency measurements in nanoseconds for each
    stage of the inference pipeline, as well as the total latency."""

    lapped_frames: int = 0
    """The total number of frames lapped during the epoch."""

    dropped_frames: int = 0
    """The total number of frames dropped during the epoch."""

    gc_pause_ns: int = 0
    """The total time spent in garbage collection pauses during the epoch."""

    gc_blocks: int = 0
    """The total number of allocation blocks created during the epoch."""

    rss_bytes: int = 0
    """The total number of allocated RSS bytes during the epoch."""

    fan_pwm: int = 0
    """The current fan PWM value during the epoch."""

    terminated: bool = False
    """A flag indicating whether the telemetry thread should terminate."""

    def __init__(self):
        """Creates a new TelemetryEpoch with six HdrHistogram instances for
        recording latency measurements in nanoseconds. Each histogram is
        initialised to track values from 1 nanosecond to 60 seconds with 3
        significant figures of precision."""

        try:
            self.histograms = [
                HdrHistogram(1, 60_000_000_000, 3)
                for _ in range(self.NUM_LATENCY_MEASURES)
            ]
        except Exception as e:
            raise RuntimeError("Failed to create HdrHistogram for epoch") from e

        self.lapped_frames = 0
        self.dropped_frames = 0
        self.gc_pause_ns = 0
        self.gc_blocks = 0
        self.rss_bytes = 0

    def reset(self):
        """Resets the histograms and allocation statistics for the epoch."""

        for histogram in self.histograms:
            histogram.reset()

        self.lapped_frames = 0
        self.dropped_frames = 0
        self.gc_pause_ns = 0
        self.gc_blocks = 0
        self.rss_bytes = 0
        self.fan_pwm = 0


class TelemetryWriter:
    """Records latency measurements into an epoch buffer. Used by the inference
    thread to publish the results to the telemetry thread for processing, and to
    receive a fresh buffer for the next epoch."""

    SWAP_INTERVAL: int = 1_000_000_000
    """The interval at which the active epoch buffer is swapped with a fresh
    buffer received from the telemetry thread."""

    sender: Sender[TelemetryEpoch]
    """The sender channel for publishing the current epoch to the telemetry
    thread for processing."""

    receiver: Receiver[TelemetryEpoch]
    """The receiver channel for receiving a fresh epoch from the telemetry
    thread."""

    last_swap: int
    """The timestamp of the last buffer swap, used to determine when to next
    swap the buffers."""

    last_lapped_frames: int
    """The number of frames lapped since the last call to record, used to
    calculate the number of lapped frames for the current epoch."""

    last_dropped_frames: int
    """The number of frames dropped since the last call to record, used to
    calculate the number of dropped frames for the current epoch."""

    current_epoch: TelemetryEpoch
    """The currently active telemetry epoch for recording latency
    measurements."""

    is_terminated: bool
    """A flag indicating whether the telemetry thread has been signaled to
    terminate."""

    def __init__(
        self, sender: Sender[TelemetryEpoch], receiver: Receiver[TelemetryEpoch]
    ):
        """Constructs a new TelemetryWriter with the specified sender and
        receiver channels for double-buffered histogram processing.

        Args:
            sender: The sender channel for publishing the populated epoch to the
            telemetry thread for processing.
            receiver: The receiver channel for receiving a fresh epoch buffer
            from the telemetry thread."""

        self.sender = sender
        self.receiver = receiver
        self.last_swap = time.perf_counter_ns()
        self.last_lapped_frames = 0
        self.last_dropped_frames = 0
        self.current_epoch = receiver.receive()
        self.is_terminated = False

    def record(
        self, ts: list[int], lapped_frames: int, dropped_frames: int
    ) -> None:
        """Records latency measurements into the currently active telemetry
        epoch. If at least one second has elapsed since the last buffer swap,
        the active buffer is swapped with a fresh buffer received from the
        telemetry thread.

        Args:
            ts: An array of six timestamps in nanoseconds, representing the
            start and end times of each stage of the inference pipeline, as well
            as the total latency.
            lapped_frames: The total number of frames lapped.
            dropped_frames: The total number of frames dropped."""

        if self.is_terminated:
            return

        if time.perf_counter_ns() - self.last_swap >= self.SWAP_INTERVAL:
            self.swap_buffers()

        for i in range(TelemetryEpoch.NUM_LATENCY_MEASURES - 1):
            nanos = saturating_sub(ts[i + 1], ts[i])

            try:
                self.current_epoch.histograms[i].record_value(nanos)
            except Exception as e:
                raise RuntimeError(
                    f"Failed to record latency value {nanos} ns for measure {i}"
                ) from e

        total_nanos = saturating_sub(
            ts[TelemetryEpoch.TOTAL_LATENCY],
            ts[TelemetryEpoch.UNBOUNDED_QUEUE_WAIT],
        )

        try:
            self.current_epoch.histograms[
                TelemetryEpoch.TOTAL_LATENCY
            ].record_value(total_nanos)
        except Exception as e:
            raise RuntimeError(
                f"Failed to record total latency value {total_nanos} ns"
            ) from e

        newly_lapped = saturating_sub(lapped_frames, self.last_lapped_frames)
        self.current_epoch.lapped_frames += newly_lapped
        self.last_lapped_frames = lapped_frames

        newly_dropped = saturating_sub(dropped_frames, self.last_dropped_frames)
        self.current_epoch.dropped_frames += newly_dropped
        self.last_dropped_frames = dropped_frames

    def swap_buffers(self):
        """Swaps the active histogram buffer with the cleared buffer received
        from the background thread. The populated buffer is sent to the
        background thread for processing, and the timestamp of the last swap is
        updated."""

        """Try to receive the fresh epoch from the telemetry thread. If the
        channel is empty, we skip the swap and continue recording into the
        current epoch."""

        # Reset timer to guarantee one check per second.
        self.last_swap = time.perf_counter_ns()

        epoch = self.receiver.try_receive()

        if epoch != None:
            self.sender.send(self.current_epoch)
            self.current_epoch = epoch

    def terminate(self):
        """Signals the telemetry thread to terminate by setting the terminated
        flag in the current epoch and sending it to the telemetry thread. It
        needs to be guaranteed that the epoch is sent, regardless of whether the
        telemetry thread is blocked or not, to ensure that the telemetry thread
        can exit gracefully. Therefore swap_buffers() is not called here, and
        instead the termination epoch is sent directly."""

        if self.is_terminated:
            return

        self.is_terminated = True
        self.current_epoch.terminated = True
        self.sender.send(self.current_epoch)


class Csv:
    filename: str
    file: object
    writer: object

    def __init__(self, filename: str):
        self.filename = filename
        self.file = open(filename, 'w', newline='')
        self.writer = csv.writer(self.file)

        LABELS: Final[list[str]] = [
            'unbounded_wait',
            'idiomatic_wait',
            'inference_exec',
            'mpsc_wait',
            'fusion_exec',
            'total_latency',
        ]
        SUFFIXES: Final[list[str]] = ['p50', 'p99', 'p99_9', 'max']

        headings: list[str] = ['timestamp_ns']

        headings.extend(
            [f'{label}_{suffix}' for label in LABELS for suffix in SUFFIXES]
        )

        headings.extend(
            [
                'lapped_frames',
                'dropped_frames',
                'gc_pause_ns',
                'gc_blocks',
                'rss_bytes',
                'fan_pwm',
            ]
        )

        self.writer.writerow(headings)
        self.file.flush()

    def write_record(self, epoch: TelemetryEpoch, timestamp_ns: int):
        record: list[float] = [timestamp_ns]

        for i in range(TelemetryEpoch.NUM_LATENCY_MEASURES):
            histogram = epoch.histograms[i]
            record.append(histogram.get_value_at_percentile(50))
            record.append(histogram.get_value_at_percentile(99))
            record.append(histogram.get_value_at_percentile(99.9))
            record.append(histogram.get_max_value())

        record.extend(
            [
                epoch.lapped_frames,
                epoch.dropped_frames,
                epoch.gc_pause_ns,
                epoch.gc_blocks,
                epoch.rss_bytes,
                epoch.fan_pwm,
            ]
        )

        self.writer.writerow(record)
        self.file.flush()


def spawn_telemetry_thread(
    stream_name: str,
    sender: Sender[TelemetryEpoch],
    receiver: Receiver[TelemetryEpoch],
) -> threading.Thread:
    for i in range(3):
        epoch = TelemetryEpoch()
        sender.send(epoch)

    # Telemetry is written to a CSV file for later analysis.
    csv_filename = f"telemetry_{stream_name}.csv"

    try:
        csv = Csv(csv_filename)
    except Exception as e:
        raise RuntimeError(
            f"Failed to create CSV file for telemetry file '{csv_filename}'"
        ) from e

    def telemetry_thread():
        PAGE_SIZE: Final[int] = resource.getpagesize()

        last_gc_pause_ns = 0
        last_gc_blocks = 0

        while True:
            epoch = receiver.receive()
            timestamp_ns = time.time_ns()

            # If the `terminated` flag is set, we break out of the loop and exit
            # the telemetry thread gracefully.
            if epoch.terminated:
                break

            # Now the inference thread is no longer updating the completed
            # epoch, we can save it.

            current_gc_pause_ns = gc.pause_ns
            epoch.gc_pause_ns = saturating_sub(
                current_gc_pause_ns, last_gc_pause_ns
            )
            last_gc_pause_ns = current_gc_pause_ns

            current_gc_blocks = sys.getallocatedblocks()
            epoch.gc_blocks = saturating_sub(current_gc_blocks, last_gc_blocks)
            last_gc_blocks = current_gc_blocks

            try:
                with open('/proc/self/statm', 'r') as f:
                    rss_pages = int(f.read().split()[1])
                    epoch.rss_bytes = rss_pages * PAGE_SIZE
            except Exception:
                raise RuntimeError(
                    "Failed to read RSS bytes from /proc/self/statm"
                ) from e

            try:
                with open('/sys/class/hwmon/hwmon0/pwm1', 'r') as f:
                    epoch.fan_pwm = int(f.read().strip())
            except Exception:
                raise RuntimeError(
                    "Failed to read RSS bytes from /sys/class/hwmon/hwmon0/pwm1"
                ) from e

            try:
                csv.write_record(epoch, timestamp_ns)
            except Exception as e:
                raise RuntimeError(
                    f"Failed to write telemetry record to CSV file "
                    f"'{csv_filename}'"
                ) from e

            epoch.reset()

            try:
                sender.send(epoch)
            except Exception as e:
                raise RuntimeError(
                    "Failed to send clean telemetry epoch"
                ) from e

    try:
        thread = threading.Thread(
            target=telemetry_thread,
            name=f"telemetry_{stream_name}",
            daemon=True,
        )
        thread.start()
    except Exception as e:
        raise RuntimeError(
            f"Failed to spawn telemetry thread for '{stream_name}'"
        ) from e

    return thread
