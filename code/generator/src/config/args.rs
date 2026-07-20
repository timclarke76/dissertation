use clap::Parser;

/// Command line arguments. If not provided, the application will use
/// from the configuration file (`settings.toml`).
#[derive(Parser)]
pub struct Args {
    /// Path to the settings file.
    #[arg(short, long)]
    pub settings: Option<String>,

    /// Which core to run the application on.
    #[arg(short, long)]
    pub core: Option<usize>,

    /// Real-time priority of the application.
    #[arg(short, long)]
    pub priority: Option<u8>,

    /// Simulated CPU load multiplier.
    #[arg(short, long)]
    pub load: Option<f32>,

    /// How long to generate events before exiting (in seconds). This is used in
    /// conjuction with each event's FPS to determine how many events to
    /// generate. If not provided, the application will run indefinitely.
    #[arg(short, long)]
    pub runtime_seconds: Option<usize>,

    /// Output file path for the report.
    #[arg(short, long)]
    pub output: Option<String>,

    /// Whether to run the application in headless mode (without a GUI). Running
    /// in headless mode will disable the TUI at the end, and allow the
    /// generator to exit immediately.
    #[arg(short, long)]
    pub headless: Option<bool>,
}
