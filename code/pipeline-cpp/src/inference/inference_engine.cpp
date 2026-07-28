#include <mutex>
#include <numeric>
#include <stdexcept>

#include "inference_engine.h"

InferenceEngine::InferenceEngine(const std::string& model_path,
  const std::vector<int64_t>& input_shape,
  void* input_buffer)
  : input_shape_(input_shape)
  , output_shape_{ 1, 4 }
  , output_data_(4, 0.0f)
{
  static Ort::Env env(ORT_LOGGING_LEVEL_ERROR, "pipeline");
  static std::mutex trt_init_mutex;

  Ort::SessionOptions sess_options;
  sess_options.SetIntraOpNumThreads(1);
  sess_options.SetGraphOptimizationLevel(
    GraphOptimizationLevel::ORT_ENABLE_ALL);

  OrtTensorRTProviderOptions trt_options{};
  trt_options.device_id = 0;
  trt_options.trt_engine_cache_enable = 1;
  trt_options.trt_engine_cache_path = "./trt_cache";
  trt_options.trt_fp16_enable = 1;
  sess_options.AppendExecutionProvider_TensorRT(trt_options);

  {
    std::lock_guard<std::mutex> lock(trt_init_mutex);
    session_ = Ort::Session(env, model_path.c_str(), sess_options);
  }

  Ort::MemoryInfo memory_info =
    Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
  io_binding_ = Ort::IoBinding(session_);

  const size_t window_size_items = static_cast<size_t>(std::accumulate(
    input_shape_.begin(), input_shape_.end(), 1LL, std::multiplies<int64_t>()));
  const size_t window_size_bytes = window_size_items * sizeof(float);

  io_binding_.BindInput("input",
    Ort::Value::CreateTensor(memory_info,
      input_buffer,
      window_size_bytes,
      input_shape_.data(),
      input_shape_.size(),
      ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT));

  io_binding_.BindOutput("output",
    Ort::Value::CreateTensor<float>(memory_info,
      output_data_.data(),
      output_data_.size(),
      output_shape_.data(),
      output_shape_.size()));
}

void
InferenceEngine::run()
{
  session_.Run(Ort::RunOptions{ nullptr }, io_binding_);
}
