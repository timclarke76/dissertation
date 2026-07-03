#pragma once
#include <chrono>
#include <thread>

#include <os/channel.h>
#include <os/shm.h>
#include <queue.h>

/// Spawns a new thread that continuously processes frames from a shared memory
/// buffer and sends them to the next stage in the pipeline, simulating
/// inference processing time for each frame.
///
/// \param stream_name The name of the stream associated with this inference
/// thread.
/// \param queue A reference to the Queue from which frames will be popped for
/// processing.
/// \param sender A reference to the Sender used to send processed frames to the
/// next stage in the pipeline.
/// \param time The simulated time taken to process each frame.
/// \param window The number of frames to process in each inference window.
/// \return A std::jthread representing the spawned inference thread.
std::jthread
spawn_inference_thread(const std::string& stream_name,
  Queue<ShmBuffer::Frame>& queue,
  Sender<ShmBuffer::Frame>& sender,
  const std::chrono::duration<double>& time,
  const size_t window);
