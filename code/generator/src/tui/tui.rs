use std::io::stdout;

use anyhow::{Context, Result};
use num_format::{Locale, ToFormattedString};

use crossterm::{
    ExecutableCommand,
    event::{self, Event, KeyCode},
    terminal::{
        EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode,
        enable_raw_mode,
    },
};

use ratatui::{
    prelude::*,
    widgets::{Block, Borders, Cell, Paragraph, Row, Table},
};

use crate::events::Report;

/// Renders the report using Ratatui. The overview and summary sections are
/// displayed at the top (left and right respectively), and the events table is
/// displayed below. The user can exit the TUI by pressing 'q' or 'Esc'.
/// #Args
/// * `report`: The report to render in the TUI.
/// #Returns
/// A `Result` indicating success or failure.
pub fn render_report(report: &Report) -> Result<()> {
    enable_raw_mode().context("Failed to enable raw mode")?;
    stdout()
        .execute(EnterAlternateScreen)
        .context("Failed to enter alternate screen")?;

    let mut terminal = Terminal::new(CrosstermBackend::new(stdout()))
        .context("Failed to create terminal")?;

    loop {
        terminal.draw(|frame| {
            let vertical_areas = Layout::default()
                .direction(Direction::Vertical)
                .constraints([Constraint::Length(7), Constraint::Min(0)])
                .split(frame.area());

            let top_areas = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([
                    Constraint::Percentage(34),
                    Constraint::Percentage(66),
                ])
                .split(vertical_areas[0]);

            render_overview(frame, top_areas[0], &report);
            render_summary(frame, top_areas[1], &report);
            render_events(frame, vertical_areas[1], &report);
        })?;

        if event::poll(std::time::Duration::from_millis(15))? {
            if let Event::Key(key) = event::read()? {
                if key.code == KeyCode::Char('q') || key.code == KeyCode::Esc {
                    break;
                }
            }
        }
    }

    disable_raw_mode().context("Failed to disable raw mode")?;
    stdout()
        .execute(LeaveAlternateScreen)
        .context("Failed to leave alternate screen")?;

    Ok(())
}

/// Renders the overview section in the specified area of the terminal frame.
/// #Args
/// * `frame`: The terminal frame to render the overview in.
/// * `area`: The rectangular area of the terminal to render the overview.
/// * `report`: The report containing the overview data to display.
fn render_overview(frame: &mut Frame, area: Rect, report: &Report) {
    let overview = vec![
        Line::from(vec![
            Span::raw("CPU Core   : "),
            Span::raw(report.core.to_string()),
        ]),
        Line::from(vec![
            Span::raw("Priority   : "),
            Span::raw(report.priority.to_string()),
        ]),
        Line::from(vec![
            Span::raw("Load       : "),
            Span::raw(format!("{:.2}", report.load)),
        ]),
        Line::from(vec![
            Span::raw("Min Sleep  : "),
            Span::raw(format!("{} ns", report.min_sleep_nanos)),
        ]),
        Line::from(vec![
            Span::raw("Runtime    : "),
            Span::raw(
                report
                    .runtime_seconds
                    .map_or("∞".to_string(), |s| format!("{} s", s)),
            ),
        ]),
    ];

    let overview = Paragraph::new(overview)
        .block(Block::default().borders(Borders::ALL).title(" OVERVIEW "));

    frame.render_widget(overview, area);
}

/// Renders the summary section in the specified area of the terminal frame.
/// #Args
/// * `frame`: The terminal frame to render the summary in.
/// * `area`: The rectangular area of the terminal to render the summary.
/// * `report`: The report containing the summary data to display.
fn render_summary(frame: &mut Frame, area: Rect, report: &Report) {
    let elapsed_time_secs = report.elapsed_time_nanos as f64 / 1_000_000_000.0;

    let summary = vec![
        Line::from(vec![
            Span::raw("Elapsed Time       : "),
            Span::raw(format!("{:.4} s", elapsed_time_secs)),
        ]),
        Line::from(vec![
            Span::raw("Main Loop Cycles   : "),
            Span::raw(report.main_loop_cycles.to_formatted_string(&Locale::en)),
        ]),
        Line::from(vec![
            Span::raw("Drain Cycles       : "),
            Span::raw(report.drain_cycles.to_formatted_string(&Locale::en)),
        ]),
        Line::from(vec![
            Span::raw("OS Sleep Calls     : "),
            Span::raw(report.sleep_calls.to_formatted_string(&Locale::en)),
        ]),
        Line::from(vec![
            Span::raw("CPU Spin Calls     : "),
            Span::raw(report.spin_calls.to_formatted_string(&Locale::en)),
        ]),
    ];

    let summary = Paragraph::new(summary)
        .block(Block::default().borders(Borders::ALL).title(" SUMMARY "));

    frame.render_widget(summary, area);
}

/// Renders the events table in the specified area of the terminal frame.
/// #Args
/// * `frame`: The terminal frame to render the events table in.
/// * `area`: The rectangular area of the terminal to render the events table.
/// * `report`: The report containing the events data to display.
fn render_events(frame: &mut Frame, area: Rect, report: &Report) {
    let elapsed_time_secs = report.elapsed_time_nanos as f64 / 1_000_000_000.0;

    let header_cells = [
        "Name",
        "Seed",
        "Frame Length",
        "Frame Size",
        "Pool Capacity",
        "Buffer Capacity",
        "Runs",
        "Frequency",
    ]
    .iter()
    .map(|h| {
        Cell::from(*h).style(
            Style::default()
                .fg(Color::Yellow)
                .add_modifier(Modifier::BOLD),
        )
    });

    let header = Row::new(header_cells).height(1);

    let rows = report.events.iter().map(|item| {
        let hz = item.run_count as f64 / elapsed_time_secs;

        Row::new(vec![
            Cell::from(item.name.clone()),
            Cell::from(item.seed.to_string()),
            Cell::from(item.frame_length.to_formatted_string(&Locale::en)),
            Cell::from(format_bytes(item.frame_size_bytes)),
            Cell::from(
                item.pool_capacity_frames.to_formatted_string(&Locale::en),
            ),
            Cell::from(
                item.buffer_capacity_frames.to_formatted_string(&Locale::en),
            ),
            Cell::from(item.run_count.to_formatted_string(&Locale::en)),
            Cell::from(format!("{:.2} Hz", hz)),
        ])
    });

    let table = Table::new(
        rows,
        [
            Constraint::Percentage(16),
            Constraint::Percentage(12),
            Constraint::Percentage(12),
            Constraint::Percentage(12),
            Constraint::Percentage(12),
            Constraint::Percentage(12),
            Constraint::Percentage(12),
            Constraint::Percentage(12),
        ],
    )
    .header(header)
    .block(Block::default().borders(Borders::ALL).title(" EVENTS "));

    frame.render_widget(table, area);
}

/// Formats a byte size into a human-readable string with appropriate units (B,
/// KB, MB, GB, TB, PB, EB).
/// #Args
/// * `bytes`: The size in bytes to format.
/// #Returns
/// A `String` representing the formatted byte size with units.
fn format_bytes(bytes: usize) -> String {
    let suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB"];
    let num = bytes as f64;
    let base: f64 = 1024.0;

    let i = (num.ln() / base.ln()).floor() as usize;
    let i = i.min(suffixes.len() - 1);

    if i == 0 {
        format!("{} {}", bytes, suffixes[i])
    } else {
        let value = num / base.powi(i as i32);
        format!("{:.2} {}", value, suffixes[i])
    }
}
