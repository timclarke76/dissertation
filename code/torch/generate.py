#!/usr/bin/env python3

import os
import warnings

import torch
import torch.nn as nn

warnings.simplefilter(action='ignore', category=FutureWarning)


class RgbDummy(nn.Module):
    """ A dummy CNN for the RGB stream. This is a placeholder model that
    simulates the computational workload of a real vision model without
    performing any meaningful inference. If we export a model that does nothing
    (i.e. just passes input to output), TensorRT will optimise the network out
    of existence."""

    def __init__(self):
        super().__init__()
        self.net = nn.Sequential(
            nn.Conv2d(3, 16, kernel_size=3, stride=2, padding=1),
            nn.ReLU(), # standard non-linear operation
            nn.AdaptiveAvgPool2d((1, 1)),
            nn.Flatten(),
            nn.Linear(16, 4),
        )

    def forward(self, x):
        return self.net(x)


class ImuDummy(nn.Module):
    """ A dummy CNN for the IMU streams. This is a placeholder model that
    simulates the computational workload of a real vision model without
    performing any meaningful inference. If we export a model that does nothing
    (i.e. just passes input to output), TensorRT will optimise the network out
    of existence."""

    def __init__(self, window_size):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(3, 32),
            nn.ReLU(),
            nn.Flatten(),
            nn.Linear(window_size * 32, 4),
        )

    def forward(self, x):
        return self.net(x)


CONFIG = {
    "RGB": {
        "model": RgbDummy(),
        "shape": (1, 3, 1080, 1920),
    },
    "Accelerometer": {
        "model": ImuDummy(53),
        "shape": (1, 53, 3),
    },
    "Gyroscope": {
        "model": ImuDummy(66),
        "shape": (1, 66, 3),
    },
}


if __name__ == "__main__":
    os.makedirs("models", exist_ok=True)

    for name, spec in CONFIG.items():
        onnx_path = f"models/{name}_base.onnx"
        print(f"Exporting {onnx_path} ... ", end="", flush=True)

        torch.onnx.export(
            spec["model"].eval(),
            torch.randn(*spec["shape"], dtype=torch.float32),
            onnx_path,
            input_names=["input"],
            output_names=["output"],
            dynamic_axes=None,  # prevents dynamic allocation during inference
            opset_version=17,
        )

        print(f"done")
