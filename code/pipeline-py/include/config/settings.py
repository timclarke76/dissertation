import argparse
import tomllib
from dataclasses import dataclass
from .policy import (
    BoundedQueue,
    ExponentialBackoff,
    DropOldest,
    DropNewest,
    AdaptiveDecimation,
    Policy,
)


@dataclass
class EventQueueConfig:
    """Represents the configuration for an event queue."""

    name: str
    """The name of the queue."""

    fps: int
    """The target frame rate for the queue in frames per second."""

    capacity_frames: int
    """The capacity of the queue in frames."""


@dataclass
class Settings:
    """Represents the configuration settings for the application."""

    rgb_queue_config: EventQueueConfig
    """Configuration for the RGB event queue."""

    rgb_policy: Policy
    """Policy for handling RGB events."""

    accel_queue_config: EventQueueConfig
    """Configuration for the accelerometer event queue."""

    accel_policy: Policy
    """Policy for handling accelerometer events."""

    gyro_queue_config: EventQueueConfig
    """Configuration for the gyroscope event queue."""

    gyro_policy: Policy
    """Policy for handling gyroscope events."""

    def __init__(self, args: argparse.Namespace) -> Settings:
        """Creates a new Settings instance by loading configuration from a TOML
        file specified by the args argument, and applying command-line
        arguments.

        If a setting is provided in the command-line arguments, it will override
        the corresponding value from the configuration file.

        Args:
            args: The command-line arguments that may override configuration
            settings.
        """
        try:
            with open(args.settings, 'rb') as f:
                data = tomllib.load(f)

            self.rgb_queue_config = EventQueueConfig(**data['rgb_queue_config'])
            self.rgb_policy = self._parse_policy(data['rgb_policy'])

            self.accel_queue_config = EventQueueConfig(
                **data['accel_queue_config'],
            )
            self.accel_policy = (self._parse_policy(data['accel_policy']),)

            self.gyro_queue_config = EventQueueConfig(
                **data['gyro_queue_config']
            )
            self.gyro_policy = self._parse_policy(data['gyro_policy'])
        except Exception as e:
            e.add_note(f"Settings file '{args.settings}' parsing failed.")
            raise

    def _parse_policy(self, data: dict) -> Policy:
        """Parses the policy configuration from a TOML table.

        Args:
            tbl: The TOML table containing the policy configuration.
            policy_name: The name of the policy to parse.

        Returns:
            A Policy instance containing the parsed policy.
        """
        p_type = data['type']

        if p_type == 'BoundedQueue':
            return BoundedQueue()
        elif p_type == 'ExponentialBackoff':
            return ExponentialBackoff(
                base_nanos=data['base_nanos'],
                max_nanos=data['max_nanos'],
                multiplier=data['multiplier'],
            )
        elif p_type == 'DropOldest':
            return DropOldest()
        elif p_type == 'DropNewest':
            return DropNewest()
        elif p_type == 'AdaptiveDecimation':
            return AdaptiveDecimation(
                threshold=data['threshold'],
                min_ratio=data['min_ratio'],
                max_ratio=data['max_ratio'],
            )
        else:
            raise ValueError(f"Unknown policy type: {p_type}")
