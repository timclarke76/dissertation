use anyhow::{Context, Result};
use clap::Parser;

mod config;
mod events;
mod os;
mod tui;

use config::{Args, Settings};
use events::Events;
use os::{pin_to_core, set_realtime_priority};
use tui::render_report;

fn main() -> Result<()> {
    let args = Args::try_parse()?;
    let settings = Settings::try_new("settings", args)?;

    pin_to_core(settings.core)?;
    set_realtime_priority(settings.priority)?;

    println!(
        "Pinned to CPU core {} with real-time priority {}",
        settings.core, settings.priority
    );
    println!("Simulated CPU Load Factor: {:.2}", settings.load);

    let mut events = Events::try_new(&settings)?;
    println!("Running event loop, use Ctrl-C to cancel.");
    let report = events.run()?;

    let json = serde_json::to_string_pretty(&report)
        .context("Failed to serialise report to JSON")?;
    std::fs::write(&settings.output, &json).with_context(|| {
        format!("Failed to write report to file: '{}'", settings.output)
    })?;

    println!("Report written to: {}", settings.output);

    if settings.headless {
        Ok(())
    }
    else {
        render_report(&report).context("Error rendering report")
    }
}
