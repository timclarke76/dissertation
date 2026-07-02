use clap::Parser;

/// Parses command line arguments for the application.
///
/// If the `--settings` argument is not provided, it defaults to
/// "settings.toml".
#[derive(Parser)]
pub struct Args {
    /// The name of the settings file.
    #[arg(short, long, default_value = "settings.toml")]
    pub settings: Option<String>,
}
