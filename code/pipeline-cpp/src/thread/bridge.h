#pragma once

#include <cstddef>
#include <string>
#include <thread>

#include <config/policy.h>
#include <os/shm.h>
#include <queue.h>

/// \brief Spawns a new thread that continuously reads frames from a shared
/// memory buffer and pushes them into a queue, applying the specified
/// backpressure policy when the queue is full.
///
/// \param shm_name The name of the shared memory buffer to read from.
/// \param stream_id The stream ID associated with this bridge.
/// \param queue A reference to the Queue where frames will be pushed.
/// \param policy The backpressure Policy to apply when the queue is full.
/// \return A std::jthread representing the spawned thread.
std::jthread
spawn_bridge_thread(const std::string& shm_name,
  const size_t stream_id,
  Queue<ShmBuffer::Frame>& queue,
  const Policy& policy);
