#pragma once
#include <memory>
#include <thread>

#include <os/channel.h>
#include <os/shm.h>
#include <queue.h>

/// Spawns a new thread that continuously processes frames from a shared memory
/// buffer and sends them to the next stage in the pipeline, running inference
/// using the specified ONNX model.
///
/// \param stream_name The name of the stream associated with this inference
/// thread.
/// \param queue A shared pointer to the Queue from which frames will be popped.
/// \param sender The Sender used to send processed frames to the next stage in
/// the pipeline.
/// \param model_path The path to the ONNX model file used for inference.
/// \param window_frames The number of frames to process in each inference
/// window.
/// \param frame_shape The shape of the frames being processed, suitable for
/// tensor.
/// \param item_size_bytes The size of each frame item in bytes (e.g., 1 byte
/// for uint8_t, 4 bytes for float).
/// \return A std::jthread representing the spawned inference thread.
std::jthread
spawn_inference_thread(const std::string& stream_name,
  std::shared_ptr<Queue<ShmBuffer::Frame>> queue,
  Sender<ShmBuffer::Frame> sender,
  const std::string& model_path,
  const size_t window_frames,
  const std::vector<int64_t>& frame_shape,
  const size_t item_size_bytes);
