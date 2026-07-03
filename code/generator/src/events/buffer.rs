use std::{
    ffi::CString,
    fs::File,
    num::NonZeroUsize,
    os::fd::{FromRawFd, IntoRawFd},
    ptr::NonNull,
    sync::atomic::{AtomicU64, Ordering},
};

use anyhow::{Context, Result};

use nix::{
    fcntl::OFlag,
    sys::mman::{
        MapFlags, ProtFlags, mlock, mmap, munmap, shm_open, shm_unlink,
    },
    sys::stat::Mode,
};

/// Represents the header of the shared memory buffer. It is aligned to 64 bytes
/// to ensure proper memory alignment for atomic operations.
#[repr(C, align(64))]
pub struct ShmHeader {
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

    /// The pipeline stage of the shared memory buffer. This field is used to
    /// synchronise between the generator and the pipeline. Initialised to zero,
    /// it is incremented to one when the pipeline is ready to receive data, and
    /// incremented to two when the generator has finished writing data.
    pub pipeline_stage: AtomicU64,
}

impl ShmHeader {
    /// The generator is waiting for the pipeline to be ready to receive data.
    pub const WAITING: u64 = 0;

    /// The pipeline is ready to receive data from the generator.
    pub const READY: u64 = 1;

    /// The generator has finished writing data to the shared memory buffer.
    pub const FINISHED: u64 = 2;
}

/// Represents a shared memory buffer that can be used for communication between
/// processes using a shared memory file.
pub struct ShmBuffer {
    /// The name of the shared memory buffer, used to identify the shared memory
    /// file. It should be unique to avoid conflicts with other shared memory
    /// buffers in the system.
    name: String,

    /// The C-compatible string representation of the shared memory buffer name.
    /// This field is used when calling `shm_unlink`.
    c_name: CString,

    /// A pointer to the header of the shared memory buffer.
    header: *mut ShmHeader,

    /// A pointer to the data section of the shared memory buffer.
    data_ptr: *mut u8,

    /// The size of each frame in bytes. Duplicated from the header for
    /// convenience and to avoid dereferencing the header pointer multiple
    /// times.
    frame_size_bytes: usize,

    /// The total capacity of the data section of the shared memory buffer, in
    /// bytes.
    capacity_bytes: usize,

    /// The current write offset, from `data_ptr`, in bytes.
    write_offset_bytes: usize,
}

impl ShmBuffer {
    /// The size of the header of the shared memory buffer, in bytes.
    const HEADER_SIZE: usize = std::mem::size_of::<ShmHeader>();

    /// Creates a new shared memory buffer with the specified name, frame size,
    /// and capacity in frames.
    /// #Args
    /// * `name` - The name of the shared memory buffer, used to identify the
    ///   shared memory file. It should be unique to avoid conflicts with other
    ///   shared memory buffers in the system.
    /// * `frame_size_bytes` - The size of each frame in bytes.
    /// * `capacity_frames` - The total number of frames that the buffer can
    ///   hold.
    /// #Returns
    /// A `Result` containing the `ShmBuffer` if successful, or an error if the
    /// shared memory buffer could not be created or initialised.
    pub fn try_new(
        name: impl Into<String>,
        frame_size_bytes: usize,
        capacity_frames: usize,
    ) -> Result<Self> {
        let name = name.into();
        let c_name = CString::new(name.as_str())
            .with_context(|| format!("Invalid shared memory name: '{name}'"))?;

        let capacity_bytes = capacity_frames
            .checked_mul(frame_size_bytes)
            .with_context(|| {
                format!(
                    "Requested buffer capacity ({capacity_frames} \
                    frames * {frame_size_bytes} bytes per frame) larger than \
                    usize::MAX"
                )
            })?;

        let total_bytes = Self::HEADER_SIZE
            .checked_add(capacity_bytes)
            .with_context(|| {
                format!(
                    "Total size ({} bytes header + {capacity_bytes} \
                    bytes data) larger than usize::MAX",
                    Self::HEADER_SIZE,
                )
            })?;

        let shm_ptr = Self::open_shm_file(&name, total_bytes)?;
        let header = Self::initialise_header(
            shm_ptr,
            frame_size_bytes,
            capacity_frames,
        )?;

        Ok(Self {
            name,
            c_name,
            header,
            data_ptr: unsafe { shm_ptr.add(Self::HEADER_SIZE) },
            frame_size_bytes,
            capacity_bytes,
            write_offset_bytes: 0,
        })
    }

    /// Opens a shared memory file with the specified name and length in bytes.
    /// The mapped memory is zeroed out, and the memory is locked into RAM to
    /// prevent it from being swapped out.
    /// #Args
    /// * `name` - The name of the shared memory buffer, used to identify the
    ///   shared memory file. It should be unique to avoid conflicts with other
    ///   shared memory buffers in the system.
    /// * `size_bytes` - The size of the shared memory file, in bytes.
    /// #Returns
    /// A `Result` containing a pointer to the mapped memory if successful, or
    /// an error if the shared memory file could not be created, opened, or
    /// mapped into the process's address space.
    fn open_shm_file(name: &String, size_bytes: usize) -> Result<*mut u8> {
        let c_name = CString::new(name.as_str())
            .with_context(|| format!("Invalid shared memory name: '{name}'"))?;

        // Create or open the shared memory file with read and write
        // permissions.
        let shm_fd = shm_open(
            c_name.as_c_str(),
            OFlag::O_CREAT | OFlag::O_RDWR | OFlag::O_TRUNC,
            Mode::S_IRUSR | Mode::S_IWUSR,
        )
        .with_context(|| format!("Failed to open shared memory: '{name}'"))?;

        // Convert the file descriptor into a `File` object so that the size of
        // the shared memory buffer can be set.
        let file = unsafe { File::from_raw_fd(shm_fd.into_raw_fd()) };

        file.set_len(size_bytes as u64).with_context(|| {
            format!(
                "Failed to set shared memory size \
                for '{name}' to {size_bytes} bytes"
            )
        })?;

        // Map the shared memory file into the process's address space with read
        // and write permissions.
        let shm_ptr = unsafe {
            let mem = mmap(
                None,
                NonZeroUsize::new(size_bytes).unwrap(),
                ProtFlags::PROT_WRITE | ProtFlags::PROT_READ,
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

        // Zero out the mapped memory and lock it into RAM to prevent swapping.
        // This prevents latency spikes due to page faults. Note that this may
        // require the following permissions set in the file
        // `/etc/security/limits.conf`:
        //     * hard memlock unlimited
        //     * soft memlock unlimited
        unsafe {
            std::ptr::write_bytes(shm_ptr, 0, size_bytes);

            let lock_ptr =
                NonNull::new_unchecked(shm_ptr as *mut std::ffi::c_void);

            mlock(lock_ptr, size_bytes).with_context(|| {
                format!(
                    "Failed to mlock shared memory for '{name}' \
                    with capacity {size_bytes} bytes"
                )
            })?;
        }

        Ok(shm_ptr)
    }

    /// Initialises the header of the shared memory buffer.
    /// #Args
    /// * `shm_ptr` - A pointer to the start of the shared memory buffer.
    /// * `frame_size_bytes` - The size of each frame in bytes.
    /// * `capacity_frames` - The total number of frames that the buffer can
    ///   hold.
    /// #Returns
    /// A `Result` containing a pointer to the initialised header if successful,
    /// or an error if the header could not be initialised.
    fn initialise_header(
        shm_ptr: *mut u8,
        frame_size_bytes: usize,
        capacity_frames: usize,
    ) -> Result<*mut ShmHeader> {
        let header = shm_ptr as *mut ShmHeader;

        unsafe {
            (*header).magic = 0x45444745; // "EDGE"
            (*header).version = 1;
            (*header).frame_size_bytes = frame_size_bytes as u32;
            (*header).capacity_frames = capacity_frames as u32;
            std::ptr::write(&mut (*header).seq_num, AtomicU64::new(0));
            std::ptr::write(
                &mut (*header).pipeline_stage,
                AtomicU64::new(ShmHeader::WAITING),
            );
        }

        Ok(header)
    }

    /// Returns a mutable slice of the shared memory buffer for writing data.
    /// The caller is responsible for committing the written data by calling the
    /// `commit` method after writing to the slice.
    /// #Returns
    /// A mutable slice of the shared memory buffer for writing data, with a
    /// length equal to the frame size in bytes.
    pub fn get_mut_slice(&mut self) -> &mut [u8] {
        if self.write_offset_bytes + self.frame_size_bytes > self.capacity_bytes
        {
            self.write_offset_bytes = 0;
        }

        unsafe {
            let offset_ptr = self.data_ptr.add(self.write_offset_bytes);
            self.write_offset_bytes += self.frame_size_bytes;
            std::slice::from_raw_parts_mut(offset_ptr, self.frame_size_bytes)
        }
    }

    /// Commits the written data to the shared memory buffer by atomically
    /// incrementing the sequence number in the header. This signals to any
    /// consumers that a new frame is ready for processing.
    pub fn commit(&mut self) {
        unsafe {
            (*self.header).seq_num.fetch_add(1, Ordering::Release);
        }
    }

    /// Checks if the pipeline is ready to receive data from the generator by
    /// reading the `pipeline_stage` field in the header. Returns `true` if the
    /// pipeline is ready, or `false` otherwise.
    pub fn is_pipeline_ready(&self) -> bool {
        unsafe {
            (*self.header).pipeline_stage.load(Ordering::Acquire)
                == ShmHeader::READY
        }
    }

    /// Sets the `pipeline_stage` field in the header to `FINISHED`, indicating
    /// that the generator has finished writing data to the shared memory
    /// buffer.
    pub fn set_pipeline_finished(&mut self) {
        unsafe {
            (*self.header)
                .pipeline_stage
                .store(ShmHeader::FINISHED, Ordering::Release);
        }
    }
}

impl Drop for ShmBuffer {
    /// Cleans up the shared memory buffer by unmapping the memory and unlinking
    /// the shared memory file. Called automatically when the `ShmBuffer`
    /// instance goes out of scope or is dropped. Any errors during cleanup are
    /// logged to standard error.
    fn drop(&mut self) {
        unsafe {
            match NonNull::new(self.header as *mut std::ffi::c_void) {
                Some(ptr) => {
                    let len = Self::HEADER_SIZE + self.capacity_bytes;

                    let _ = munmap(ptr, len).unwrap_or_else(|e| {
                        eprintln!(
                            "Failed to unmap shared memory '{}': {e}",
                            self.name
                        );
                    });
                }
                None => {
                    eprintln!(
                        "Shared memory header pointer is null for '{}'",
                        self.name
                    );
                }
            }
        }

        shm_unlink(self.c_name.as_c_str()).unwrap_or_else(|e| {
            eprintln!("Failed to unlink shared memory '{}': {e}", self.name);
        });
    }
}
