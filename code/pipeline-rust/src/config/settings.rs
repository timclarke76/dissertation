use anyhow::{Context, Result};
use config::Config;
use serde::Deserialize;

use super::args::Args;
use crate::thread::Policy;

/// Represents the configuration settings for the application.
#[derive(Deserialize)]
pub struct Settings {
    /// Configuration for the RGB event queue.
    pub rgb_queue: EventQueueConfig,

    /// Policy for handling RGB events.
    pub rgb_policy: Policy,

    /// Configuration for the accelerometer event queue.
    pub accelerometer_queue: EventQueueConfig,

    /// Policy for handling accelerometer events.
    pub accelerometer_policy: Policy,

    /// Configuration for the gyroscope event queue.
    pub gyroscope_queue: EventQueueConfig,

    /// Policy for handling gyroscope events.
    pub gyroscope_policy: Policy,
}

#[derive(Deserialize)]
pub struct EventQueueConfig {
    /// The name of the queue.
    pub name: String,

    /// The capacity of the queue in frames.
    pub capacity_frames: usize,
}

impl Settings {
    /// Creates a new `Settings` instance by loading configuration from a file
    /// and applying command-line arguments. If a setting is provided in the
    /// command-line arguments, it will override the corresponding value from
    /// the configuration file.
    /// #Args
    /// * `default_source`: The default path to the configuration file.
    /// * `args`: The command-line arguments that may override configuration
    ///   settings.
    /// #Returns
    /// A `Result` containing the `Settings` instance if successful, or an
    /// error if the configuration could not be loaded or deserialized.
    pub fn try_new<S: AsRef<str>>(
        default_source: S,
        args: Args,
    ) -> Result<Self> {
        let source = args
            .settings
            .unwrap_or_else(|| default_source.as_ref().to_string());

        let settings = Config::builder()
            .add_source(config::File::with_name(&source))
            .build()
            .context("Failed to build configuration")?;

        let settings: Self = settings
            .try_deserialize()
            .context("Failed to deserialise configuration")?;

        Ok(settings)
    }
}
