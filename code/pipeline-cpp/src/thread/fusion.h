#pragma once
#include <string>
#include <thread>
#include <vector>

#include <os/channel.h>
#include <os/shm.h>

/// \brief Spawns a thread for late fusion of frames from a shared memory queue.
///
/// Fusion is only performed when an RGB frame is received, with the latest
/// accelerometer and gyrometer frames.
///
/// \param receiver A reference to the Receiver used to receive frames from the
/// inference threads.
/// \param stream_names A vector of stream names to be used for telemetry and
/// thread identification. The first name in the vector is used for the RGB
/// stream, the second for the accelerometer stream, and the third for the
/// gyroscope stream.
/// \return A std::jthread representing the spawned thread.
std::jthread
spawn_fusion_thread(Receiver<ShmBuffer::Frame> receiver,
  const std::vector<std::string>& stream_names);
