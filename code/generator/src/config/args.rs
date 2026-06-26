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

    /// Output file path for the report.
    #[arg(short, long)]
    pub output: Option<String>,
}
