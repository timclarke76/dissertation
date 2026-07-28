import os
import sys
import numpy as np
import threading

fd_stderr = sys.stderr.fileno()
saved_stderr = os.dup(fd_stderr)
devnull = os.open(os.devnull, os.O_WRONLY)
os.dup2(devnull, fd_stderr)
import onnxruntime as ort

os.dup2(saved_stderr, fd_stderr)
os.close(devnull)
os.close(saved_stderr)

_trt_init_lock = threading.Lock()


class InferenceEngine:
    def __init__(self, model_path: str, input_buffer: np.ndarray):
        """Constructs an InferenceEngine object that initialises an ONNX Runtime
        session with the specified model and input buffer.

        Args:
            model_path: The path to the ONNX model file.
            input_buffer: A numpy array that will be used as the input buffer
            for the model. The shape and dtype of this array should match the
            expected input of the model.
        """
        sess_options = ort.SessionOptions()
        sess_options.intra_op_num_threads = 1
        sess_options.graph_optimization_level = (
            ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        )

        trt_options = {
            "device_id": 0,
            "trt_engine_cache_enable": True,
            "trt_engine_cache_path": "./trt_cache",
            "trt_fp16_enable": True,
        }

        with _trt_init_lock:
            self.session = ort.InferenceSession(
                model_path,
                sess_options=sess_options,
                providers=[("TensorrtExecutionProvider", trt_options)],
            )

        self.io_binding = self.session.io_binding()
        self.io_binding.bind_cpu_input("input", input_buffer)
        self.output_data = np.zeros((1, 4), dtype=np.float32)

        self.io_binding.bind_output(
            name="output",
            device_type="cpu",
            device_id=0,
            element_type=np.float32,
            shape=self.output_data.shape,
            buffer_ptr=self.output_data.ctypes.data,
        )

    def run(self):
        """Runs inference on the input buffer using the ONNX Runtime session."""
        self.session.run_with_iobinding(self.io_binding)
