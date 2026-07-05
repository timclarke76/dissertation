import argparse
from dataclasses import dataclass


@dataclass
class Args:
    """Parses command line arguments for the application.

    If the `--settings` argument is not provided, it defaults to
    'settings.toml'."""

    settings: str
    """The name of the settings file."""

    def __init__(self):
        """Constructs an Args object and parses command line arguments.

        Initialises an ArgumentParser and parses the provided arguments."""

        parser = argparse.ArgumentParser(description="Python pipeline.")

        parser.add_argument(
            '-s',
            '--settings',
            type=str,
            default='settings.toml',
            help="Path to the settings TOML file",
        )

        args = parser.parse_args()
        self.settings = args.settings
