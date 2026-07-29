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

    /// Whether to precompile the TensorRT models. If true, the pipeline exits
    /// after completion.
    #[arg(
        short,
        long,
        num_args(0..=1),
        default_missing_value = "true",
        default_value = "false",
        require_equals = true
    )]
    pub precompile: bool,
}
