use serde::{Deserialize, Serialize};

/// A report of the system's performance and events.
#[derive(Serialize, Deserialize)]
pub struct Report {
    /// The CPU core on which the application was running.
    pub core: usize,

    /// The real-time priority of the application.
    pub priority: u8,

    /// The simulated CPU load multiplier.
    pub load: f32,

    /// The minimum sleep duration in nanoseconds for the main loop to use the
    /// `sleep` function instead of spinning.
    pub min_sleep_nanos: u64,

    /// The configure runtime duration in seconds. If not set, the application
    /// ran indefinitely until interrupted.
    pub runtime_seconds: Option<usize>,

    /// The actual runtime duration in nanoseconds.
    pub elapsed_time_nanos: u64,

    /// The number of cycles spent in the main loop.
    pub main_loop_cycles: u64,

    /// The number of cycles spent in the drain loop.
    pub drain_cycles: u64,

    /// The number of times the application called the sleep function.
    pub sleep_calls: u64,

    /// The number of times the application called the spin function.
    pub spin_calls: u64,

    /// The list of event reports generated during the application's execution.
    pub events: Vec<EventReport>,
}

/// A report of a single event's performance and configuration.
#[derive(Serialize, Deserialize)]
pub struct EventReport {
    /// The name of the event.
    pub name: String,

    /// The seed value for the event's random number generator.
    pub seed: u64,

    /// The length of each frame.
    pub frame_length: usize,

    /// The size of each frame in bytes.
    pub frame_size_bytes: usize,

    /// The capacity of the event's pool in frames.
    pub pool_capacity_frames: usize,

    /// The capacity of the event's buffer in frames.
    pub buffer_capacity_frames: usize,

    /// The number of times the event was run during the application's
    /// execution.
    pub run_count: u64,
}
