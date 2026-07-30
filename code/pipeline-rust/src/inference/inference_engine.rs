use anyhow::{Context, Result};
use ndarray::Array;
use ort::{
    execution_providers::TensorRTExecutionProvider,
    session::{IoBinding, Session, builder::GraphOptimizationLevel},
    value::Tensor,
};
use std::sync::Mutex;

static TRT_INIT_MUTEX: Mutex<()> = Mutex::new(());

pub struct InferenceEngine {
    io_binding: IoBinding,
    session: Session,
    _input_tensor: Tensor<f32>,

    input_ptr: *mut f32,
    input_size: usize,
    output_ptr: *const f32,
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
        let input_size: usize = shape_usize.iter().product();

        let mut io_binding = session
            .create_binding()
            .context("Failed to create IoBinding")?;

        let mut input_array =
            Array::from_shape_vec(shape_usize, vec![0.0f32; input_size])
                .context("Failed to create input array")?;
        let input_ptr = input_array.as_mut_ptr();
        let input_tensor = Tensor::from_array(input_array)
            .context("Failed to create input tensor")?;
        io_binding
            .bind_input("input", &input_tensor)
            .context("Failed to bind input")?;

        let output_array = Array::from_shape_vec(vec![1, 4], vec![0.0f32; 4])
            .context("Failed to create output array")?;
        let output_ptr = output_array.as_ptr();
        let output_tensor = Tensor::from_array(output_array)
            .context("Failed to create output tensor")?;
        io_binding
            .bind_output("output", output_tensor)
            .context("Failed to bind output")?;

        Ok(Self {
            io_binding,
            session,
            _input_tensor: input_tensor,
            input_ptr,
            input_size,
            output_ptr,
        })
    }

    /// Returns a mutable slice to the input buffer for the inference engine.
    ///
    /// Allows the client to modify the input data before running inference.
    ///
    /// Returns a mutable slice of f32 values representing the input buffer.
    pub fn input_buffer_mut(&mut self) -> &mut [f32] {
        unsafe {
            std::slice::from_raw_parts_mut(self.input_ptr, self.input_size)
        }
    }

    /// Runs inference on the contained tensor data using the ONNX Runtime
    /// session.
    ///
    /// Returns an array of 4 f32 values representing the output of the
    /// inference, or an error if the inference fails.
    pub fn run(&mut self) -> Result<[f32; 4]> {
        self.io_binding
            .synchronize_inputs()
            .context("Failed to synchronise inputs")?;

        self.session
            .run_binding(&self.io_binding)
            .context("Failed to run inference")?;

        self.io_binding
            .synchronize_outputs()
            .context("Failed to synchronise outputs")?;

        let mut result = [0.0f32; 4];
        unsafe {
            std::ptr::copy_nonoverlapping(
                self.output_ptr,
                result.as_mut_ptr(),
                4,
            );
        }

        Ok(result)
    }
}
