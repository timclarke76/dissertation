use anyhow::{Context, Result};

use nix::{
    errno::Errno,
    sys::time::TimeSpec,
    time::{ClockId, ClockNanosleepFlags, clock_gettime, clock_nanosleep},
};

/// Returns the current monotonic time in nanoseconds.
/// #Returns
/// A `Result` containing the current monotonic time in nanoseconds, or an error
/// if the operation fails.
pub fn now_nanos() -> Result<u64> {
    let ts = clock_gettime(ClockId::CLOCK_MONOTONIC)
        .context("Failed to get monotonic time")?;

    Ok((ts.tv_sec() as u64 * 1_000_000_000) + (ts.tv_nsec() as u64))
}

/// Sleeps until the absolute monotonic time in nanoseconds is reached.
/// #Args
/// `target_nanos` - The absolute monotonic time in nanoseconds to sleep until.
/// #Returns
/// A `Result` indicating success or failure. Returns an error if the sleep
/// operation fails for reasons other than being interrupted by a signal.
pub fn sleep_until_nanos(target_nanos: u64) -> Result<()> {
    let wake_up_time = TimeSpec::new(
        (target_nanos / 1_000_000_000) as i64,
        (target_nanos % 1_000_000_000) as i64,
    );

    loop {
        match clock_nanosleep(
            ClockId::CLOCK_MONOTONIC,
            ClockNanosleepFlags::TIMER_ABSTIME,
            &wake_up_time,
        ) {
            Ok(_) => return Ok(()),
            Err(Errno::EINTR) => continue, // Retry on an interrupt signal
            Err(e) => return Err(e).context("Sleeping until target time"),
        }
    }
}
