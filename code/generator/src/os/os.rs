use anyhow::{Context, Result, anyhow, bail};

use thread_priority::{
    ThreadPriority, ThreadPriorityValue, thread_native_id,
    unix::{
        RealtimeThreadSchedulePolicy, ThreadSchedulePolicy,
        set_thread_priority_and_policy,
    },
};

/// Pins the current thread to the specified CPU core.
/// Use the command `lscpu` to list available CPU cores and their IDs.
/// Use the command `watch -n 0.5 mpstat -P ALL 1 1` to monitor CPU core usage
/// in real-time.
/// #Args
/// `core_id` - The ID of the CPU core to pin the thread to.
/// #Returns
/// A `Result` indicating success or failure. Returns an error if the core ID is
/// out of bounds or if the pinning operation fails.
pub fn pin_to_core(core_id: usize) -> Result<()> {
    let core_ids =
        core_affinity::get_core_ids().context("Failed to get CPU core IDs")?;

    if core_id >= core_ids.len() {
        bail!(
            "Core ID {core_id} is out of bounds (Max available: {})",
            core_ids.len() - 1
        );
    }

    if !core_affinity::set_for_current(core_ids[core_id]) {
        bail!("Failed to pin to CPU core {core_id}");
    }

    Ok(())
}

/// Sets the real-time priority of the current thread to the specified level
/// (1-99).
/// #Args
/// `priority` - The desired real-time priority level (1-99).
/// #Returns
/// A `Result` indicating success or failure. Returns an error if the priority
/// level is out of bounds or if the operation fails.
pub fn set_realtime_priority(priority: u8) -> Result<()> {
    let thread_id = thread_native_id();

    let priority_value: ThreadPriorityValue =
        priority.try_into().map_err(|_| {
            anyhow!("Priority {} is out of bounds. Must be 0-99.", priority)
        })?;
    let priority_value = ThreadPriority::Crossplatform(priority_value);

    let policy =
        ThreadSchedulePolicy::Realtime(RealtimeThreadSchedulePolicy::Fifo);

    set_thread_priority_and_policy(thread_id, priority_value, policy)
        .with_context(|| {
            format!(
                "Failed to set thread priority to {} with policy {:?}",
                priority, policy
            )
        })?;

    Ok(())
}
