#!/usr/bin/env python3

import os
import sys
import numpy as np

# Prevent a wall of diagnostic messages from being printed, that are not
# relevant and can be safely ignored. This is a workaround for a known issue in
# ONNX Runtime.
fd_stderr = sys.stderr.fileno()
saved_stderr = os.dup(fd_stderr)
devnull = os.open(os.devnull, os.O_WRONLY)
os.dup2(devnull, fd_stderr)
import onnxruntime as ort
os.dup2(saved_stderr, fd_stderr)
os.close(devnull)
os.close(saved_stderr)

ort.set_default_logger_severity(3)

CONFIG = {
    "RGB": {"shape": (1, 3, 1080, 1920)},
    "Accelerometer": { "shape": (1, 53, 3)},
    "Gyroscope": {"shape": (1, 66, 3)},
    "Fusion": {"shape": (1, 12)},
}

os.makedirs("./trt_cache", exist_ok=True)

for name, spec in CONFIG.items():
    epctx_path = f"./models/{name}_epctx.onnx"
    print(f"Exporting {epctx_path} ... ", end="", flush=True)

    trt_options = {
        "device_id": 0,
        "trt_engine_cache_enable": True,
        "trt_engine_cache_path": "./trt_cache",
        "trt_dump_ep_context_model": True,
        "trt_ep_context_file_path": epctx_path,
        # Downcast to FP16 (half precision) for greater efficiency.
        "trt_fp16_enable": True,
        # Restrict the compiler's memory-search aggressiveness.
        "trt_builder_optimization_level": 3,
    }

    # Run a single inference pass through TensorRT to trigger
    # the compilation of the engine and dump the context.
    session = ort.InferenceSession(
        f"./models/{name}_base.onnx",
        providers=[("TensorrtExecutionProvider", trt_options)]
    )

    session.run(None,
        {"input": np.random.randn(*spec["shape"]).astype(np.float32)})

    print(f"done")
