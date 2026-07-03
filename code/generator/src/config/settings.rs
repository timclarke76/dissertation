use anyhow::{Context, Result};
use config::Config;
use serde::Deserialize;

use super::args::Args;

/// Represents the configuration settings for the application.
#[derive(Deserialize)]
pub struct Settings {
    /// The CPU core to pin the application to.
    pub core: usize,

    /// The real-time priority of the application.
    pub priority: u8,

    /// The simulated CPU load multiplier. A value of 1.0 means normal load,
    /// while values greater than 1.0 simulate higher load.
    pub load: f32,

    /// The minimum sleep duration in nanoseconds for the main loop to use the
    /// `sleep` function instead of spinning. The prevents the `sleep` function
    /// from returning immediately.
    pub min_sleep_nanos: u64,

    /// How long to generate events before exiting (in seconds). This is used in
    /// conjuction with each event's FPS to determine how many events to
    /// generate. If not provided, the application will run indefinitely.
    pub runtime_seconds: Option<usize>,

    /// The output file path for the report.
    pub output: String,

    /// The list of event configurations.
    pub events: Vec<EventConfig>,
}

/// Represents the configuration for a single event.
#[derive(Deserialize)]
pub struct EventConfig {
    /// The name of the event.
    pub name: String,

    /// The seed value for the event's random number generator.
    pub seed: u64,

    /// The length of each frame.
    pub frame_length: usize,

    /// The capacity of the event's pool in frames.
    pub pool_capacity_frames: usize,

    /// The capacity of the event's buffer in frames.
    pub buffer_capacity_frames: usize,

    /// The frames per second (FPS) rate for the event.
    pub fps: f32,

    /// The data type configuration for the event, which can be either Integer
    /// or Float.
    #[serde(flatten)]
    pub data_type: EventDataType,
}

/// Represents the data type configuration for an event, which can be either
/// Integer or Float.
#[derive(Deserialize)]
#[serde(untagged)]
pub enum EventDataType {
    /// Represents an Integer data type configuration with minimum and maximum
    /// values.
    Integer { min: i64, max: i64 },

    /// Represents a Float data type configuration with minimum and maximum
    /// values.
    Float { min: f64, max: f64 },
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
    pub fn try_new(
        default_source: impl Into<String>,
        args: Args,
    ) -> Result<Self> {
        let source = args.settings.unwrap_or_else(|| default_source.into());

        let settings = Config::builder()
            .add_source(config::File::with_name(&source))
            .build()
            .context("Failed to build configuration")?;

        let mut settings: Self = settings
            .try_deserialize()
            .context("Failed to deserialise configuration")?;

        if let Some(core) = args.core {
            settings.core = core;
        }

        if let Some(priority) = args.priority {
            settings.priority = priority;
        }

        if let Some(runtime_seconds) = args.runtime_seconds {
            settings.runtime_seconds = Some(runtime_seconds);
        }

        if let Some(load) = args.load {
            settings.load = load;
        }

        if let Some(output) = args.output {
            settings.output = output;
        }

        Ok(settings)
    }
}
