from dataclasses import dataclass
from typing import Literal


@dataclass
class BoundedQueue:
    """Blocks the producer until space is available in the consumer buffer."""

    type: Literal['BoundedQueue'] = 'BoundedQueue'


@dataclass
class ExponentialBackoff:
    """Waits a short time before retrying to insert the data, with the wait
    time doubling with each retry."""

    base_nanos: int
    """The base wait time in nanoseconds before retrying to insert data into
    the consumer buffer."""

    max_nanos: int
    """The maximum accumulated wait time in nanoseconds before giving up and
    dropping the data."""

    multiplier: float
    """The multiplier to apply to the wait time after each retry. For example,
    a multiplier of 2.0 will double the wait time after each retry."""

    type: Literal['ExponentialBackoff'] = 'ExponentialBackoff'


@dataclass
class DropOldest:
    """Drops the oldest data in the consumer buffer to make room for new
    data."""

    type: Literal['DropOldest'] = 'DropOldest'


@dataclass
class DropNewest:
    """Drops incoming data when the buffer is full."""

    type: Literal['DropNewest'] = 'DropNewest'


@dataclass
class AdaptiveDecimation:
    """Dynamically downsamples the data stream (i.e. queueing only every nth
    event) to reduce pressure on the consumer buffer while preserving the
    temporal continuity of the data."""

    threshold: int
    """The threshold length of the consumer buffer above which decimation is
    applied. When the buffer length exceeds this threshold, only every nth frame
    is queued, and the rest are discarded before attempting to push to the
    queue."""

    min_ratio: int
    """The minimum decimation ratio to apply when the consumer buffer is above
    the threshold. For example, a min_ratio of 2 means that only every 2nd frame
    will be queued when the buffer length is at the threshold. Used in
    conjunction with max_ratio to scale the decimation ratio based on how deep
    into the "danger zone" (the region between the threshold and the queue's
    capacity) we are."""

    max_ratio: int
    """The maximum decimation ratio to apply when the consumer buffer is full.
    For example, a max_ratio of 10 means that only every 10th frame will be
    queued when the buffer is full."""

    type: Literal['AdaptiveDecimation'] = 'AdaptiveDecimation'


"""Defines the policy for handling data when the consumer buffer is full."""
Policy = (
    BoundedQueue
    | ExponentialBackoff
    | DropOldest
    | DropNewest
    | AdaptiveDecimation
)
