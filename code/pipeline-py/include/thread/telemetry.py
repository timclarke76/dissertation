import csv
from dataclasses import dataclass
import threading
import time
from typing import Final

from hdrh.histogram import HdrHistogram

from include.os import Sender, Receiver, saturating_sub


class TelemetryEpoch:
    """A telemetry epoch that contains six HdrHistogram instances for recording
    latency measurements in nanoseconds. Each histogram tracks latency for a
    specific stage of the inference pipeline, as well as the total latency."""

    UNBOUNDED_QUEUE_WAIT: int = 0
    """The index of the histogram for unbounded queue wait latency."""

    IDIOMATIC_QUEUE_WAIT: int = 1
    """The index of the histogram for idiomatic queue wait latency."""

    DATA_PREPARATION: int = 2
    """The index of the histogram for data preparation latency."""

    INFERENCE: int = 3
    """The index of the histogram for inference latency."""

    FUSION: int = 4
    """The index of the histogram for fusion latency."""

    TOTAL: int = 5
    """The index of the histogram for total latency."""

    NUM_LATENCY_MEASURES: int = 6
    """The number of latency measures tracked in an epoch."""

    latency_nanos: list[HdrHistogram]
    """The histograms for recording latency measurements in nanoseconds for each
    stage of the inference pipeline, as well as the total latency."""

    allocated_bytes: int = 0
    """The total number of bytes allocated during the epoch."""

    allocation_count: int = 0
    """The total number of allocations made during the epoch."""

    freed_bytes: int = 0
    """The total number of bytes freed during the epoch."""

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
            e.add_note("Failed to create HdrHistogram for epoch: {e}")
            raise

    def reset(self):
        """Resets the histograms and allocation statistics for the epoch."""

        for histogram in self.histograms:
            histogram.reset()

        self.allocated_bytes = 0
        self.allocation_count = 0
        self.freed_bytes = 0


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

    current_epoch: TelemetryEpoch
    """The currently active telemetry epoch for recording latency
    measurements."""

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
        self.current_epoch = receiver.receive()

    def record(self, ts: list[int]) -> None:
        """Records latency measurements into the currently active telemetry
        epoch. If at least one second has elapsed since the last buffer swap,
        the active buffer is swapped with a fresh buffer received from the
        telemetry thread.

        Args:
            ts: An array of six timestamps in nanoseconds, representing the
            start and end times of each stage of the inference pipeline, as well
            as the total latency."""

        if time.perf_counter_ns() - self.last_swap >= self.SWAP_INTERVAL:
            self.swap_buffers()

        for i in range(TelemetryEpoch.NUM_LATENCY_MEASURES - 1):
            nanos = saturating_sub(ts[i + 1], ts[i])

            try:
                self.current_epoch.histograms[i].record_value(nanos)
            except Exception as e:
                e.add_note(
                    "Failed to record latency value "
                    f"{nanos} ns for measure {i}: {e}"
                )
                raise

        total_nanos = saturating_sub(
            ts[TelemetryEpoch.TOTAL], ts[TelemetryEpoch.UNBOUNDED_QUEUE_WAIT]
        )

        try:
            self.current_epoch.histograms[TelemetryEpoch.TOTAL].record_value(
                total_nanos
            )
        except Exception as e:
            e.add_note(
                f"Failed to record total latency value {total_nanos} ns: {e}"
            )
            raise

    def swap_buffers(self):
        """Swaps the active histogram buffer with the cleared buffer received
        from the background thread. The populated buffer is sent to the
        background thread for processing, and the timestamp of the last swap is
        updated."""

        """Try to receive the fresh epoch from the telemetry thread. If the
        channel is empty, we skip the swap and continue recording into the
        current epoch."""
        epoch = self.receiver.try_receive()

        if epoch != None:
            self.last_swap = time.perf_counter_ns()
            self.sender.send(self.current_epoch)
            self.current_epoch = epoch

    def terminate(self):
        """Signals the telemetry thread to terminate by setting the terminated
        flag in the current epoch and sending it to the telemetry thread."""

        self.current_epoch.terminated = True
        self.swap_buffers()


class Csv:
    filename: str

    def __init__(self, filename: str):
        self.filename = filename

        with open(filename, 'w') as f:
            LABELS: Final[list[str]] = [
                "unbounded",
                "idiomatic",
                "data",
                "inference",
                "fusion",
                "total",
            ]
            SUFFIXES: Final[list[str]] = ["p50", "p99", "p99_9", "max"]
            HEADINGS: Final[list[str]] = [
                f"{label}_{suffix}" for label in LABELS for suffix in SUFFIXES
            ]

            csv.writer(f).writerow(HEADINGS)

    def write_record(self, epoch: TelemetryEpoch):
        with open(self.filename, 'a') as f:
            record: list[float] = []

            for i in range(TelemetryEpoch.NUM_LATENCY_MEASURES):
                histogram = epoch.histograms[i]
                record.append(histogram.get_value_at_percentile(50))
                record.append(histogram.get_value_at_percentile(99))
                record.append(histogram.get_value_at_percentile(99.9))
                record.append(histogram.get_max_value())

            record.append(epoch.allocated_bytes)
            record.append(epoch.allocation_count)
            record.append(epoch.freed_bytes)

            csv.writer(f).writerow(record)

def spawn_telemetry_thread(
    stream_name: str,
    sender: Sender[TelemetryEpoch],
    receiver: Receiver[TelemetryEpoch],
) -> threading.Thread:
    for i in range(2):
        epoch = TelemetryEpoch()
        sender.send(epoch)

    # Telemetry is written to a CSV file for later analysis.
    csv_filename = f"telemetry_{stream_name}.csv"

    try:
        csv = Csv(csv_filename)
    except Exception as e:
        e.add_note(
            "Failed to create CSV file for "
            f"telemetry file '{csv_filename}': {e}")
        raise

    def telemetry_thread():
        last_allocated_bytes = 0
        last_allocation_count = 0
        last_freed_bytes = 0

        while True:
            epoch = receiver.receive()

            if epoch.terminated:
                break

            current_allocated_bytes = 0
            epoch.allocated_bytes = saturating_sub(
                current_allocated_bytes, last_allocated_bytes
            )
            last_allocated_bytes = current_allocated_bytes

            current_allocation_count = 0
            epoch.allocation_count = saturating_sub(
                current_allocation_count, last_allocation_count
            )
            last_allocation_count = current_allocation_count

            current_freed_bytes = 0
            epoch.freed_bytes = saturating_sub(
                current_freed_bytes, last_freed_bytes
            )
            last_freed_bytes = current_freed_bytes

            try:
                csv.write_record(epoch)
            except Exception as e:
                e.add_note(
                    f"Failed to write telemetry record to CSV file "
                    f"'{csv_filename}': {e}"
                )
                raise

            epoch.reset()

            try:
                sender.send(epoch)
            except Exception as e:
                e.add_note("Failed to send clean telemetry epoch")
                raise

    try:
        thread = threading.Thread(
            target=telemetry_thread,
            name=f"telemetry_{stream_name}",
            daemon=True,
        )
        thread.start()
    except Exception as e:
        e.add_note(f"Failed to spawn telemetry thread for '{stream_name}': {e}")
        raise

    return thread
