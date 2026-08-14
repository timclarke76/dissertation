use std::{
    hint::spin_loop,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
};

use anyhow::{Context, Result};
use signal_hook::flag;

use crate::{
    config::{EventDataType, Settings},
    os::{now_nanos, sleep_until_nanos},
};

use super::{
    event::{Event, EventTrait},
    report::{EventReport, Report},
};

/// Represents a collection of events that can be run in a loop. Supports
/// exiting the loop after a specified runtime duration, or when interrupted by
/// a signal (Ctrl-C). The events are executed based on their next scheduled run
/// time, and the loop sleeps or spins depending on how long before the next
/// event is due to be run.
pub struct Events {
    // The CPU core on which the application is running. Only used for creating
    // the report.
    core: usize,

    // The real-time priority of the application. Only used for creating the
    // report.
    priority: u8,

    // The simulated CPU load multiplier.
    load: f32,

    // The vector of events to be executed in the loop.
    events: Vec<Box<dyn EventTrait>>,

    // The minimum sleep duration in nanoseconds for the main loop to use the
    // `sleep` function instead of spinning. This prevents the `sleep` function
    // from returning immediately, thus preventing excessive CPU usage.
    min_sleep_nanos: u64,

    // The optional runtime duration in seconds. If set, the application will
    // run for the specified duration and then exit. If not set, the application
    // will run virtually indefinitely until interrupted.
    runtime_seconds: Option<usize>,

    // An atomic boolean flag that indicates whether the application has been
    // interrupted by a signal (Ctrl-C). Used to exit the main loop and drain
    // any remaining events before exiting.
    is_interrupted: Arc<AtomicBool>,
}

impl Events {
    /// Creates a new `Events` instance based on the provided settings.
    /// Initialises the events according to their configurations, and prepares
    /// them for execution.
    /// #Args
    /// * `settings` - A reference to the `Settings` struct containing the
    ///   configuration for the events and runtime parameters.
    /// #Returns
    /// A `Result` containing the new `Events` instance if successful, or an
    /// error if any event fails to initialise.
    pub fn try_new(settings: &Settings) -> Result<Self> {
        let mut events: Vec<Box<dyn EventTrait>> = Vec::new();

        for config in &settings.events {
            match config.data_type {
                EventDataType::Integer { min, max } => {
                    let event = Event::try_new(
                        &config.name,
                        config.seed,
                        config.frame_length,
                        config.pool_capacity_frames,
                        config.buffer_capacity_frames,
                        config.fps * settings.load,
                        min as u8,
                        max as u8,
                        settings.runtime_seconds,
                    )
                    .with_context(|| {
                        format!(
                            "Failed to create Integer event '{}'",
                            config.name
                        )
                    })?;

                    events.push(Box::new(event));
                }

                EventDataType::Float { min, max } => {
                    let event = Event::try_new(
                        &config.name,
                        config.seed,
                        config.frame_length,
                        config.pool_capacity_frames,
                        config.buffer_capacity_frames,
                        config.fps * settings.load,
                        min as f32,
                        max as f32,
                        settings.runtime_seconds,
                    )
                    .with_context(|| {
                        format!(
                            "Failed to create Float event '{}'",
                            config.name
                        )
                    })?;

                    events.push(Box::new(event));
                }
            }
        }

        // Set up a signal handler to allow a graceful exit on Ctrl-C
        let is_interrupted = Arc::new(AtomicBool::new(false));

        flag::register(
            signal_hook::consts::SIGINT,
            Arc::clone(&is_interrupted),
        )
        .context("Error registering SIGINT handler")?;

        flag::register(
            signal_hook::consts::SIGTERM,
            Arc::clone(&is_interrupted),
        )
        .context("Error registering SIGTERM handler")?;

        Ok(Self {
            core: settings.core,
            priority: settings.priority,
            load: settings.load,
            events,
            min_sleep_nanos: settings.min_sleep_nanos,
            runtime_seconds: settings.runtime_seconds,
            is_interrupted,
        })
    }

    /// Runs the main loop of the `Events` instance, executing events based on
    /// their scheduled run times. The loop continues until the specified
    /// runtime duration is reached or until interrupted by a signal (Ctrl-C).
    /// Collects performance metrics during execution and returns a `Report` at
    /// the end.
    /// #Returns
    /// A `Result` containing the `Report` if successful, or an error if any
    /// issues occur during execution.
    pub fn run(&mut self) -> Result<Report> {
        // Initialise some variables for later reporting.
        let mut curr_time_nanos: u64;
        let mut main_loop_cycles: u64 = 0;
        let mut drain_cycles: u64 = 0;
        let mut sleep_calls: u64 = 0;
        let mut spin_calls: u64 = 0;

        println!("Waiting for pipelines to connect.");
        while !self.events.iter().all(|event| event.is_pipeline_ready()) {
            std::thread::sleep(std::time::Duration::from_millis(10));

            if self.is_interrupted.load(Ordering::Relaxed) {
                return Err(anyhow::anyhow!(
                    "Interrupted while waiting for consumers to connect"
                ));
            }
        }
        println!("Pipelines connected.");

        let start_time_nanos: u64 =
            now_nanos().context("Failed to get current time for report")?;

        // Initialise all events to start immediately.
        self.events.iter_mut().for_each(|event| {
            event.set_next_run_nanos(start_time_nanos);
        });

        loop {
            curr_time_nanos =
                now_nanos().context("Failed to get current time for report")?;

            if self.is_interrupted.load(Ordering::Relaxed) {
                break;
            }

            main_loop_cycles += 1;
            drain_cycles += self.drain()?;

            let event = match self.next_event() {
                None => break,
                Some(event) => event,
            };

            let next_run_time_nanos = event.next_run_nanos();

            if next_run_time_nanos < curr_time_nanos {
                // Events are already ready to run, so loop back and drain them.
                continue;
            }

            if (next_run_time_nanos - curr_time_nanos) >= self.min_sleep_nanos {
                sleep_calls += 1;

                sleep_until_nanos(next_run_time_nanos).with_context(|| {
                    format!(
                        "Failed to sleep until next event time: {}",
                        next_run_time_nanos
                    )
                })?;
            } else {
                spin_calls += self
                    .spin_until(next_run_time_nanos)
                    .with_context(|| {
                        format!(
                            "Failed to spin until next event time: {}",
                            next_run_time_nanos
                        )
                    })?;
            }
        }

        curr_time_nanos =
            now_nanos().context("Failed to get current time for report")?;

        let events = self
            .events
            .iter()
            .map(|event| EventReport {
                name: event.name().to_string(),
                seed: event.seed(),
                frame_length: event.frame_length(),
                frame_size_bytes: event.frame_size_bytes(),
                pool_capacity_frames: event.pool_capacity_frames(),
                buffer_capacity_frames: event.buffer_capacity_frames(),
                run_count: event.run_count(),
            })
            .collect();

        let report = Report {
            core: self.core,
            priority: self.priority,
            load: self.load,
            min_sleep_nanos: self.min_sleep_nanos,
            runtime_seconds: self.runtime_seconds,
            elapsed_time_nanos: curr_time_nanos - start_time_nanos,
            main_loop_cycles: main_loop_cycles,
            drain_cycles: drain_cycles,
            sleep_calls: sleep_calls,
            spin_calls: spin_calls,
            events,
        };

        Ok(report)
    }

    /// Drains the events by executing any that are scheduled to run at or
    /// before the current time. This method continues to run events until there
    /// are no more events scheduled to run at the current time. It returns the
    /// number of cycles spent draining events.
    /// #Returns
    /// A `Result` containing the number of cycles spent draining events if
    /// successful, or an error if any issues occur during execution.
    fn drain(&mut self) -> Result<u64> {
        let mut cycles = 0;

        loop {
            if self.is_interrupted.load(Ordering::Relaxed) {
                break;
            }

            cycles += 1;

            let now =
                now_nanos().context("Failed to get current time for drain")?;

            let event = match self.next_event() {
                None => break,
                Some(event) => event,
            };

            if event.next_run_nanos() > now {
                break;
            }

            event.run().with_context(|| {
                format!("Error running event {} during drain", event.name())
            })?;
        }

        Ok(cycles)
    }

    /// Returns a mutable reference to the next event that is scheduled to run
    /// based on the earliest `next_run_nanos` value. If there are no events
    /// in the list, it returns `None`.
    /// #Returns
    /// An `Option` containing a mutable reference to the next event if one is
    /// found, or `None` if there are no events in the list.
    #[inline]
    fn next_event(&mut self) -> Option<&mut Box<dyn EventTrait>> {
        self.events
            .iter_mut()
            .filter(|e| !e.is_finished())
            .min_by_key(|e| e.next_run_nanos())
    }

    /// Spins in a tight loop, using CPU hints, until the current time is at
    /// least equal to the specified target time in nanoseconds.
    /// #Args
    /// * `target_time_nanos` - The target time in nanoseconds to spin until.
    /// #Returns
    /// A `Result` containing the number of cycles spent spinning if successful,
    /// or an error if any issues occur while getting the current time.
    fn spin_until(&self, target_time_nanos: u64) -> Result<u64> {
        let mut cycles = 0;

        loop {
            if self.is_interrupted.load(Ordering::Relaxed) {
                break;
            }

            cycles += 1;
            spin_loop();

            let now = now_nanos()
                .context("Failed to get current time for spin_until")?;

            if now >= target_time_nanos {
                break;
            }
        }

        Ok(cycles)
    }
}
