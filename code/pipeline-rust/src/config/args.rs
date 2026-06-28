use clap::Parser;

/// Command line arguments. If not provided, the application will use
/// from the configuration file (`settings.toml`).
#[derive(Parser)]
pub struct Args {
    /// Path to the settings file.
    #[arg(short, long)]
    pub settings: Option<String>,
}
