use anyhow::{Context, Result};

use nix::time::{ClockId, clock_gettime};

/// Returns the current monotonic time in nanoseconds.
/// #Returns
/// A `Result` containing the current monotonic time in nanoseconds, or an error
/// if the operation fails.
pub fn now_nanos() -> Result<u64> {
    let ts = clock_gettime(ClockId::CLOCK_MONOTONIC)
        .context("Failed to get monotonic time")?;

    Ok((ts.tv_sec() as u64 * 1_000_000_000) + (ts.tv_nsec() as u64))
}
