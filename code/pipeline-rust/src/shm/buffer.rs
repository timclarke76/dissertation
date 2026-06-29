use std::{
    ffi::CString,
    fs::File,
    os::fd::{FromRawFd, IntoRawFd},
    sync::atomic::{AtomicU64, Ordering},
};

use anyhow::{Context, Result};

use nix::{
    fcntl::OFlag,
    sys::{
        mman::{MapFlags, ProtFlags, mmap, shm_open},
        stat::Mode,
    },
};

use crate::os::now_nanos;

/// Represents the header of the shared memory buffer. It is aligned to 64 bytes
/// to ensure proper memory alignment for atomic operations.
#[repr(C, align(64))]
pub struct SharedMemoryHeader {
    /// A magic number used to identify the shared memory buffer. It is set to
    /// the ASCII representation of "EDGE" (0x45444745) to help confirm that the
    /// buffer has been correctly initialised and is valid.
    pub magic: u32,

    /// The version of the shared memory buffer. It is set to 1 for the initial
    /// version. This field allows for backward compatibility in the future.
    pub version: u32,

    /// The size of each frame in bytes.
    pub frame_size_bytes: u32,

    /// The total number of frames that the buffer can hold before wrapping
    /// around.
    pub capacity_frames: u32,

    /// The sequence number of the last written frame. This field is used to
    /// signal to consumers that a new frame has been written and is ready for
    /// processing.
    pub seq_num: AtomicU64,
}

/// Connects to a circular shared memory buffer and reads its frames.
pub struct SharedMemoryBuffer {
    /// The name of the shared memory buffer. Also used for logging and error
    /// messages.
    name: String,

    /// The stream ID associated with this buffer. Used to create the
    /// `SharedMemoryFrame` struct when reading frames.
    stream_id: usize,

    /// A pointer to the header of the shared memory buffer.
    header: *const SharedMemoryHeader,

    /// A pointer to the data section of the shared memory buffer.
    data_ptr: *const u8,

    /// The index of the next frame to read from the buffer. This is used to
    /// track the consumer's position in the circular buffer and to detect when
    /// the producer has lapped the consumer.
    frame_idx: u64,

    /// The total number of frames that the buffer can hold before wrapping
    /// around. This is duplicated from the header for performance reasons, as
    /// it avoids dereferencing the header pointer when the producer laps the
    /// consumer.
    capacity_frames: u64,

    /// The size of each frame in bytes. This is duplicated from the header for
    /// performance reasons, as it avoids dereferencing the header pointer on
    /// every frame read.
    frame_size_bytes: usize,
}

/// Represents a single frame read from the shared memory buffer.
#[derive(Clone)]
pub struct SharedMemoryFrame {
    /// The stream ID associated with this frame. Used to identify the source of
    /// the frame.
    pub stream_id: usize,

    /// The sequence number of the frame.
    pub seq_num: u64,

    /// The six timestamps associated with the frame, in nanoseconds:
    /// * t_generated: when the generator pushes to the unbounded buffer
    /// * t_bridged: when the bridge pushes to the idiomatic buffer
    /// * t_pipeline_in: when the pipeline pulls the event from the idiomatic
    ///   buffer
    /// * t_pipeline_out: when the pipeline pushes data to the ONNX Runtime for
    ///   inference
    /// * t_fusion_in: when inference completes and the pipeline begins late
    ///   fusion
    /// * t_fusion_out: when late fusion completes and the pipeline produces the
    ///   final output
    pub timestamps: [u64; 6],
}

impl SharedMemoryBuffer {
    /// The stream ID for the RGB camera frames.
    pub const RGB_STREAM_ID: usize = 0;

    /// The stream ID for the accelerometer frames.
    pub const ACCELEROMETER_STREAM_ID: usize = 1;

    /// The stream ID for the gyroscope frames.
    pub const GYROSCOPE_STREAM_ID: usize = 2;

    /// The magic number used to identify the shared memory buffer. It is set to
    /// the ASCII representation of "EDGE" (0x45444745) to help confirm that the
    /// buffer has been correctly initialised and is valid.
    const MAGIC: u32 = 0x45444745; // "EDGE" in ASCII

    /// Creates a new `SharedMemoryBuffer` by connecting to an existing shared
    /// memory buffer with the given name. The buffer must have been created by
    /// a producer process and must contain a valid `SharedMemoryHeader` at the
    /// start of the buffer. If the buffer does not exist or is invalid, an
    /// error is returned.
    /// #Args
    /// * `name` - The name of the shared memory buffer to connect to.
    /// * `stream_id` - The stream ID associated with this buffer.
    /// #Returns
    /// A `Result` containing the new `SharedMemoryBuffer`, or an error if the
    /// operation fails.
    pub fn try_new(name: impl Into<String>, stream_id: usize) -> Result<Self> {
        let name = name.into();
        let shm_ptr = Self::open_shm_file(&name)?;
        let header = shm_ptr as *const SharedMemoryHeader;

        unsafe {
            if (*header).magic != Self::MAGIC {
                anyhow::bail!(
                    "Memory corruption or invalid SharedMemoryHeader \
                    magic bytes in '{name}'"
                );
            }
        }

        Ok(Self {
            name,
            stream_id,
            header,
            data_ptr: unsafe {
                shm_ptr.add(std::mem::size_of::<SharedMemoryHeader>())
            },
            frame_idx: 0,
            capacity_frames: unsafe { (*header).capacity_frames as u64 },
            frame_size_bytes: unsafe { (*header).frame_size_bytes as usize },
        })
    }

    /// Opens the shared memory file with the given name and returns a pointer
    /// to the start of the shared memory region. The shared memory file must
    /// have been created by a producer process and must contain a valid
    /// `SharedMemoryHeader` at the start of the buffer.
    /// #Args
    /// * `name` - The name of the shared memory file to open.
    /// #Returns
    /// A `Result` containing a pointer to the start of the shared memory
    /// region, or an error if the operation fails.
    fn open_shm_file(name: &String) -> Result<*mut u8> {
        let c_name = CString::new(name.as_str())
            .with_context(|| format!("Invalid shared memory name: '{name}'"))?;

        let shm_fd =
            shm_open(c_name.as_c_str(), OFlag::O_RDONLY, Mode::empty())
                .with_context(|| {
                    format!("Failed to open shared memory: '{name}'")
                })?;

        let file = unsafe { File::from_raw_fd(shm_fd.into_raw_fd()) };
        let metadata = file.metadata().with_context(|| {
            format!("Failed to get metadata for shared memory: '{name}'")
        })?;
        let len_bytes = metadata.len() as usize;

        let shm_ptr = unsafe {
            let mem = mmap(
                None,
                std::num::NonZeroUsize::new(len_bytes).unwrap(),
                ProtFlags::PROT_READ,
                MapFlags::MAP_SHARED,
                &file,
                0,
            )
            .with_context(|| {
                format!(
                    "Failed to mmap shared memory allocation space for '{name}'"
                )
            })?;

            mem.as_ptr() as *mut u8
        };

        Ok(shm_ptr)
    }

    /// Spin-wait until the next frame is available, returning a slice to the
    /// new frame's bytes.
    ///
    /// Sleeping or blocking, using futexes, is not used to avoid OS-level
    /// context switches, which would introduce latency variance as the thread
    /// is descheduled and rescheduled again. This must not happen as it will
    /// confound the latency measurements, especially for the 2,000 Hz gyroscope
    /// data.
    ///
    /// By spin-waiting, the thread is never yielded to the OS, and the CPU
    /// remains in a high-performance state. Note that this does come at the
    /// cost of higher power consumption.
    ///
    /// #Returns
    /// A `Result` containing a `SharedMemoryFrame` with the sequence number and
    /// creation time of the next frame, or an error if the operation fails.
    pub fn next_frame(&mut self) -> Result<SharedMemoryFrame> {
        loop {
            let seq_num = unsafe {
                // The producer increments the sequence number after writing a
                // frame, using Release ordering to ensure all previous writes
                // have been flushed. The consumer uses Acquire ordering to
                // ensure it sees the latest writes to the frame data.
                (*self.header).seq_num.load(Ordering::Acquire)
            };

            if seq_num > self.frame_idx {
                if seq_num - self.frame_idx > self.capacity_frames {
                    // The producer has lapped the consumer, which means that
                    // frames have been overwritten before they could be read.
                    // Print a warning to stderr and jump ahead to the oldest
                    // surviving frame. For example, if the producer is at
                    // sequence 35 and the capacity is 30, the oldest surviving
                    // frame is at sequence 6.
                    eprintln!(
                        "[WARNING] {} producer lapped consumer by {} frames.",
                        self.name,
                        (seq_num - self.frame_idx)
                    );

                    self.frame_idx = seq_num - self.capacity_frames;
                }

                let circular_idx =
                    (self.frame_idx % self.capacity_frames) as usize;
                let data_offset = circular_idx * self.frame_size_bytes;

                let data = unsafe {
                    std::slice::from_raw_parts(
                        self.data_ptr.add(data_offset),
                        self.frame_size_bytes,
                    )
                };

                let t_bridged = now_nanos().context(
                    "Failed to get current time in \
                        nanoseconds for t_bridged",
                )?;

                let t_generated = data[0..8]
                    .try_into()
                    .context("Failed to read t_generated from frame data")?;
                let t_generated = u64::from_le_bytes(t_generated);

                self.frame_idx += 1;

                return Ok(SharedMemoryFrame {
                    stream_id: self.stream_id,
                    seq_num,
                    timestamps: [
                        t_generated,
                        t_bridged,
                        0, // t_pipeline_in
                        0, // t_pipeline_out
                        0, // t_fusion_in
                        0, // t_fusion_out
                    ],
                });
            }

            std::hint::spin_loop();
        }
    }
}
