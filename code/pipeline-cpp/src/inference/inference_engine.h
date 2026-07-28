#pragma once
#include <string>
#include <vector>

#include <onnxruntime_cxx_api.h>

class InferenceEngine
{
public:
  /// \brief Constructs an InferenceEngine object that initialises an ONNX
  /// Runtime session with the specified model and input buffer.
  ///
  /// \param model_path The path to the ONNX model file.
  /// \param input_shape The shape of the input tensor.
  /// \param input_buffer A pointer to the input buffer containing the data for
  /// inference.
  InferenceEngine(const std::string& model_path,
    const std::vector<int64_t>& input_shape,
    void* input_buffer);

  /// \brief Runs inference on the input buffer using the ONNX Runtime session.
  void run();

private:
  /// \brief The ONNX Runtime session used for running inference on the model.
  Ort::Session session_{ nullptr };

  /// \brief The IO binding used to bind input and output tensors for inference.
  Ort::IoBinding io_binding_{ nullptr };

  /// \brief A vector to hold the shape of the input tensor.
  std::vector<int64_t> input_shape_;

  /// \brief A vector to hold the shape of the output tensor.
  std::vector<int64_t> output_shape_;

  /// \brief A vector to hold the output data from the inference engine.
  std::vector<float> output_data_;
};
