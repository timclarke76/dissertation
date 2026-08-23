# A Comparative Analysis of Memory Management, Concurrency, and Performance in Edge-AI

This repository contains the source code, deterministic load generator, and
deployment scripts for a tri-stream Human Activity Recognition (HAR) pipeline
evaluated on an NVIDIA Jetson Orin Nano. 

## Abstract
This dissertation presents a systems-engineering comparison of C++20, Rust
1.97.1, and CPython 3.10.12. A functionally identical tri-stream Human Activity
Recognition pipeline was implemented in each language on an NVIDIA Jetson Orin
Nano, utilising a zero-allocation architecture. The implementations were
evaluated under varying ingestion rates, backpressure policies, and hardware
power constraints to isolate runtime latency, maximum throughput, and thermal
degradation.

The evaluation revealed that C++ and Rust achieve similar performance results
using the Jetson's unconstrained power mode, sustaining ingestion rates up to
5.5 times the native sensor rate with no dynamic memory allocation when using
Exponential Backoff. However, both compiled languages were unable to sustain
ingestion rates above 4.0 when using the Bounded Queue policy due to lock
contention. In unconstrained mode, Python reached terminal saturation at 4% of
the native rate, though this slightly improved to 6% under the 7-Watt profile.
Statistical analysis ruled out garbage collection as the cause of Python's poor
performance, indicating Global Interpreter Lock contention as the primary
bottleneck.

Analysis of the backpressure policies revealed a trade-off: flow-control
policies prevent data loss but suffer from latency deadline breaches at terminal
saturation, whereas load-shedding policies accept data loss to guarantee
deadline adherence. Alternatively, Adaptive Decimation attempts to prevent
saturation and retain temporal continuity, but at the expense of higher data
loss even at moderate ingestion rates that the pipeline could otherwise sustain
without data loss or deadline breaches. Furthermore, the evaluation showed that
deploying the compiled implementations under a constrained 7-Watt power profile
increases latency degradation when using flow-control policies due to limited
computational resources, confirming that the performance of Edge-AI pipelines is
impacted by the power constraints of the hardware.

This study recommends Rust for real-time Edge-AI deployments. It matches the
execution speed of C++ while providing compiler-enforced memory safety,
significantly reducing the maintenance overhead of complex concurrent systems.

## Repository Structure
* `/code/generator/` - Deterministic load generator (Rust)
* `/code/pipeline-cpp/` - C++20 pipeline implementation
* `/code/pipeline-py/` - CPython 3.10.12 pipeline implementation
* `/code/pipeline-rust/` - Rust 1.97.1 pipeline implementation
* `/results/` - Jupyter Notebook and data analysis scripts
* `Dockerfile` - Containerised deployment environment

## Hardware & Software Requirements
* **Hardware:** NVIDIA Jetson Orin Nano (8GB)
* **OS:** Jetson Linux 36.4.3 (Ubuntu 22.04 base)
* **Dependencies:** Docker, NVIDIA Container Toolkit (l4t-jetpack 36.4.0), CUDA 12.6, TensorRT 10.3

## Reproducibility and Execution
This suite is designed to be fully reproducible. The evaluation environment is
containerised via Docker to ensure a consistent execution environment.

1. **Deploy:** Run `./deploy.sh` with the Jetson connected via USB to compile the ONNX models and build the Docker image.
2. **Execute (Unconstrained):** SSH into the Jetson and run `./run.sh 2` to execute the suite in `MAXN_SUPER` mode.
3. **Execute (Constrained):** Reboot the Jetson, SSH in, and run `./run.sh 3` to execute the suite in 7-Watt mode.
4. **Analyse:** Run `./pull_results.sh` to retrieve the telemetry logs, convert them using `./log2csv.sh`, and launch `results/analysis.ipynb` via Jupyter Lab.
