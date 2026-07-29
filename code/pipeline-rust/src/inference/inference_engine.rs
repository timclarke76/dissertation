use anyhow::{Context, Result};
use ndarray::{ArrayViewD, IxDyn};
use ort::{
    execution_providers::TensorRTExecutionProvider,
    session::{Session, builder::GraphOptimizationLevel},
    value::TensorRef,
};
use std::sync::Mutex;

static TRT_INIT_MUTEX: Mutex<()> = Mutex::new(());

pub struct InferenceEngine {
    session: Session,
    shape_usize: Vec<usize>,
}

impl InferenceEngine {
    /// Constructs an InferenceEngine object that initialises an ONNX Runtime
    /// session with the specified model and input buffer.
    ///
    /// * `model_path` - The path to the ONNX model file.
    /// * `input_shape` - The shape of the input tensor.
    ///
    /// Returns an instance of InferenceEngine on success, or an error if the
    /// session could not be created.
    pub fn try_new(model_path: &str, input_shape: Vec<i64>) -> Result<Self> {
        let _lock = TRT_INIT_MUTEX.lock().map_err(|e| {
            anyhow::anyhow!("Failed to acquire TRT_INIT_MUTEX: {}", e)
        })?;

        let session = Session::builder()
            .map_err(|e| anyhow::anyhow!("{e}"))?
            .with_intra_threads(1)
            .map_err(|e| anyhow::anyhow!("{e}"))?
            .with_optimization_level(GraphOptimizationLevel::Level3)
            .map_err(|e| anyhow::anyhow!("{e}"))?
            .with_execution_providers([TensorRTExecutionProvider::default()
                .with_device_id(0)
                .with_fp16(true)
                .with_engine_cache(true)
                .with_engine_cache_path("./trt_cache")
                .build()])
            .map_err(|e| anyhow::anyhow!("{e}"))?
            .commit_from_file(model_path)
            .map_err(|e| {
                anyhow::anyhow!(
                    "Failed to load ONNX model into TensorRT: {}",
                    e
                )
            })?;

        let shape_usize: Vec<usize> =
            input_shape.into_iter().map(|x| x as usize).collect();

        Ok(Self {
            session,
            shape_usize,
        })
    }

    /// Runs inference on the provided tensor data using the ONNX Runtime
    /// session.
    ///
    /// * `tensor_data` - The bytes representing the input tensor data.
    ///
    /// Returns an array of 4 f32 values representing the output of the
    /// inference, or an error if the inference fails.
    pub fn run(&mut self, tensor_data: &[f32]) -> Result<[f32; 4]> {
        let dynamic_shape = IxDyn(&self.shape_usize);

        let view = ArrayViewD::from_shape(dynamic_shape, tensor_data)
            .context("Failed to create f32 ArrayView")?;
        let input = TensorRef::from_array_view(view)
            .context("Failed to create TensorRef from f32 ArrayView")?;

        let output = self
            .session
            .run(ort::inputs!["input" => input])
            .context("Failed to run inference")?;

        let (_shape, slice) = output["output"]
            .try_extract_tensor::<f32>()
            .context("Failed to extract output tensor")?;

        if slice.len() != 4 {
            anyhow::bail!(
                "Expected 4 output elements, but got {}",
                slice.len()
            );
        }

        let mut result = [0.0f32; 4];
        result.copy_from_slice(slice);

        Ok(result)
    }
}
