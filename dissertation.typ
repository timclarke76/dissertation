#import "@preview/wordometer:0.1.5": word-count, total-words

#show: word-count

#import "template.typ": template, ct, todo
#show: template.with(
  title: [AC52010 - MSc Project],
  assignment: [A Comparative Analysis of Memory Safety, Concurrency, and
    Performance in Edge-AI],
  abstractTitle: [A Comparative Analysis of Memory Safety, Concurrency, and
    Performance in Edge-AI],
)

#show "C++": box[C++]

#let wc(body) = word-count(total => [
  #body
  #set text(size: 0.8em, style: "italic")
  #align(right)[#{total.words - 1}]
])

// #set text(size: 12pt)
#columns(2, gutter: 16pt)[
#wc[
= Introduction

== Background and Context

#wc[ In recent years, Edge-AI (Edge Artificial Intelligence) has begun to move
the deployment of AI models from centralised cloud-based servers to local
devices such as sensors, mobile phones, and embedded systems. This allows for
real-time processing and reduces internet bandwidth usage, making it suitable
for applications where reduced latency is critical (e.g. fitness trackers,
autonomous vehicles, etc.), or where connectivity is unreliable or unavailable
(e.g. remote weather stations, satellite image analysis, etc.).

#todo[discuss advances in hardware acceleration]

Edge-AI deployment brings challenges in terms of resource constraints, such as
limited computational power, memory, and power requirements. Remote software
updates to maintain Edge-AI applications also come at a cost, as they can be
expensive and time-consuming, especially when dealing with a large number of
devices. These challenges make language selection an important design decision
for Edge-AI pipelines.
]

== Problem Statement

#wc[
When deploying on Edge hardware, the above listed challenges amplify the impact
of programming language choice. A language's runtime model dictates memory,
concurrency, and scheduling behaviour under load, which directly impacts
latency, throughput, and resource usage. For example, manual memory management
offers fine-grained control and increased performance, but simultaneously
increases the risk of memory leaks and undefined behaviour. Conversely, memory
management may be automated through garbage collection (GC) at the cost of
increased latency and unpredictable latency jitter.

Selecting a language for Edge-AI pipelines is often guided by familiarity or
generalised benchmarks, rather than the evaluation of runtime models under
stress with the constraints of embedded hardware. There is a lack of empirical
evidence of how specific memory management and concurrency models interact with
backpressure policies under heavy, fluctuating loads. Additionally, resource
contention and thermal throttling confounders can introduce noise that limits
the validity of naive comparisons.

This dissertation addresses this gap by providing empirical evidence and an
evaluation of pipelines deployed on resource-constrained hardware, with a focus
on the trade-offs among Rust, C++, and Python implementations of a tri-stream
Human Activity Recognition (HAR) pipeline on industry-standard Edge-AI hardware.
It focuses on three confounders: (1) language runtime models, (2) backpressure
policies under various loads, and (3) thermal/power throttling.
]

== Research Questions and Objectives

#wc[
The primary research questions are:

#text[
  #set enum(indent: 0em, numbering: n => [*RQ#n*])

+ *Runtime Performance:* How do the runtime models /*(memory and concurrency)*/
  of Rust/*(borrow checker/async runtimes)*/, C++/*(manual memory
  management/native threads)*/, and Python /*(GC/GIL)*/ influence
  latency/*(p50/p95/p99)*/, throughput, and memory consumption in a tri-stream
  HAR pipeline on Edge-AI hardware?
  // #todo[runtime models and latency percentiles might belong in the
  // methodology section]

+ *Backpressure Interaction:* How do the language-specific runtime models
  interact with different backpressure policies /*(bounded queue, drop-oldest,
  rate-limiting)*/ under varying load, and what are the trade-offs in observed
  deadline adherence, system stability, and allocator/GC pressure and
  concurrency overhead? /*#todo[backpressure policies might belong in the
  methodology section]*/

+ *Dynamic Profiling vs. Runtime Behaviour:* To what extent do dynamic
  memory/concurrency profiling metrics /*(allocation churn, GC pause duration,
  asynchronous task-switch overhead)*/ explain the observed performance
  bottlenecks and trade-offs under load? /*#todo[exact metrics might belong in
  the methodology section]*/
]

The primary research objectives are:

#text[
  #set enum(indent: 0em, numbering: n => [*RO#n*])

+ Implement a functionally identical tri-stream HAR pipeline in Rust, C++, and
  Python, ensuring optimised idiomatic implementations for each language.

+ Evaluate the performance of each implementation under controlled conditions,
  using a shared deterministic load generator, to quantify how backpressure
  policies and runtime models impact latency/*(p50/p95/p99)*/, throughput,
  memory consumption/* (RSS/PSS/USS)*/, and thermal/power dynamics under load.
  //#todo[exact metrics might belong in the methodology section]

+ Analyse runtime model overhead to explain performance differences, and derive
  empirically grounded guidance for language selection in constrained Edge-AI
  deployments. /*#todo[allocation churn, GC pause duration, async task-switch
  overhead belong in the methodology section]*/
]
]

== Research Contributions

#wc[
This dissertation offers the following contributions to software engineering for
Edge-AI systems:

#text[
  #set enum(indent: 0em, numbering: n => [*C#n*])

+ *Cross-Language Runtime Evaluation:* Addressing RQ1, this work delivers an
  empirical comparison of how Rust, C++, and Python runtime models (memory
  management and concurrency) influence latency, throughput, and memory
  consumption on resource-constrained embedded hardware.

+ *Interaction Analysis:* Addressing RQ2, this work provides a controlled
  assessment of how backpressure policies interact with runtime models under
  various loads, and identifies trade-offs between throughput and long-term
  system stability.

+ *Root-Cause Identification:* Addressing RQ3, this work presents empirical
  evidence linking dynamic memory allocation churn, GC pause duration, and
  scheduling overhead to system latency and throughput.

+ *Evidence-Based Guidelines:* Addressing findings across all research
  questions, this dissertation offers empirically grounded recommendations for
  language selection in real-time, multi-stream edge deployments.
]
]

== Scope and Limitations

#wc[
The focus of this dissertation is on the interaction of three language runtime
models (Rust, C++, and Python) with system latency and throughput, using
standardised, idiomatic implementations of a tri-stream HAR pipeline on
industry-standard Edge-AI hardware. The scope is limited to a standardised
implementation representative of real-world multi-modal processing, with
confounders limited to thermal/power throttling and queue-based backpressure
policies.

The pipeline architecture, deterministic load generator, and backpressure
mechanisms are designed for cross-platform compatibility. However, AI
acceleration, thermal behaviour, and power management are fundamentally
SoC-dependent. Consequently, the profiling and acceleration tools used during
evaluation (e.g., NVIDIA tegrastats, TensorRT) are specific to the Jetson Orin
Nano platform and cannot be directly applied across other edge devices.
]


== Dissertation Outline

#wc[
The remainder of this dissertation is structured as follows: #box[*Chapter 2*]
reviews related work, the runtime models of the target languages, and
backpressure policies. #box[*Chapter 3*] details the methodology, including the
hardware and software setup, backpressure interfaces, and profiling toolchains
to collect metrics. #box[*Chapter 4*] describes the implementation of the HAR
pipeline in each language, highlighting language-specific optimisations and
challenges. #box[*Chapter 5*] presents the results, including performance
metrics, memory allocation and GC pressure, and backpressure outcomes under
varying loads. #box[*Chapter 6*] discusses the findings, and limitations of the
study. Finally, #box[*Chapter 7*] concludes by addressing the research
questions, providing practical recommendations for language selection in Edge-AI
contexts, and suggesting directions for future work.
]
]

#wc[
= Literature Review

#todo[
- Synthetic HAR data generation.
- Backpressure policies.
- Runtime models of Rust, C++, and Python.
- Performance of Rust, C++, and Python in Edge-AI contexts.
- Thermal and power management on embedded hardware.
- Profiling tools for Edge-AI hardware.
- Previous comparative analyses of programming languages for Edge-AI.
- Previous work on language runtime models and backpressure policies.
- Best practices for Rust real-time accuracy.
]
]

#wc[
= Methodology

== Hardware and Software Environment

#wc[
=== Hardware Stack

The NVIDIA Jetson Orin Nano Super was utilised as the target Edge-AI platform.
It is a high-performance heterogeneous computing platform that is designed for
Edge-AI development in embedded systems, allowing complex AI workloads and
multi-stream pipelines to be run efficiently. The developer kit includes a
carrier board with I/O interfaces (e.g., USB, Ethernet, DisplayPort), a MicroSD
card slot for booting, and the Jetson Orin Nano module itself which includes the
following features @jetson-orin-nano:
- 6-core Arm Cortex-A78AE 64-bit CPU for general-purpose concurrent processing
- up to 67 TOPS (Tera Operations Per Second) of AI performance
- 8 GB of 128-bit LPDDR5 memory with a bandwidth of 102 GB/s
- 1024 CUDA cores for general-purpose GPU computing
- 32 Tensor cores for AI acceleration

A Waveshare IMX219-160 Camera Module @imx219-160 was used to deliver the RGB
video stream, configured to capture at #highlight[1920×1080 RGB frames at 30
FPS], and connected via MIPI CSI-2 (Mobile Industry Processor Interface Camera
Serial Interface 2). The camera captures images with a field of view (FOV) of
160#sym.degree, making it suitable for capturing a wide area for human activity
recognition after undistortion.

A Bosch Sensortec BMI088 IMU Shuttle Board 3.0 @bmi088 was used to provide
inertial measurement data, configured to capture 6-axis data, and connected via
SPI for maximum throughput. The BMI088 combines a 3-axis accelerometer and a
3-axis gyroscope, providing two complementary data streams at up to 1.6 kHz
(accelerometer) and 2.0 kHz (gyroscope).

To ensure that disk I/O did not cause bottlenecks or confound performance
comparisons, all implementations were executed from a 1TB Samsung 990 PRO PCIe
4.0 NVMe M.2 SSD @samsung-990-pro. A SanDisk "High-Endurance" microSD Card
(64GB, Class 10/U3) @sandisk-micro-sd was only used for initial device
installation and bootloading, and was unmounted after boot to prevent any
background I/O (such as writing logs) from interfering with performance
measurements.
]

#wc[
=== Software Stack

The Jetson was flashed with NVIDIA's JetPack 7.1 SDK @jetpack-7-1, which
includes Jetson Linux 38.4 @jetson-linux (which uses the Ubuntu 24.04-based root
file system), and CUDA 13.0.0, cuDNN 9.12.0, and TensorRT 10.13.3.9 for AI
inference and acceleration. The software stack versions were selected as the
most recent stable releases at the time of development, and were used for all
implementations to ensure a consistent baseline for comparison. #todo[Add ONNX
version]

*CUDA* (Compute Unified Device Architecture) @cuda provides a parallel execution
environment and programming model for heterogeneous computing systems with
NVIDIA GPUs, using Single Instruction Multiple Threads (SIMT) architecture. In
CUDA, the CPU is referred to as the _host_, and the GPU is referred to as the
_device_. CUDA clients are responsible for managing the transfer of data between
_host memory_ and _device memory_.

CUDA allows developers to write a _kernel_ function that is launched
asynchronously from the host code and executed in parallel across many threads
(using different data) on the device, enabling high-performance computing for AI
workloads. The kernel _threads_ are grouped into _thread blocks_, which in turn
are grouped into a _grid_. Each thread block is split into _warps_ of 32 threads
that are executed in lock step on a single device _Streaming Multiprocessor_
(SM).

*cuDNN* (CUDA Deep Neural Network) @cudnn is a GPU-accelerated library of
primitives for deep neural networks, that sits on top of CUDA and runs on the
device to provide higher-level abstractions and optimised implementations of
common deep learning operations (e.g., normalisation, matrix multiplication,
softmax, etc.).

*TensorRT* @tensorRT is responsible for compiling an *ONNX* (Open Neural Network
Exchange) @onnx model into a _.engine_ file, optimised to run on the Jetson GPU.

All implementations interact with the *ONNX Runtime* to load and execute the AI
model, which is responsible for the data transfer and inference orchestration on
the host, and hands off responsibility to TensorRT for inference execution on
the device. To ensure a consistent baseline, the same optimised _.engine_ file
was used across all three implementations.

Performance and overhead of the language runtime models was measured at the
boundary of the host/device memory separation, where the CPU manages the runtime
model and the SIMT architecture runs the AI workloads on the GPU. This prevents
confounding the results with hardware latency, and provides a clearer comparison
of how each language's runtime model performs under load and backpressure.

A Docker container, based on NVIDIA's official _l4t-base_ image (#ct[version]),
was used to prevent host updates to ensure that the software toolchains and
environment variables remained consistent for all implementations. #todo[Add
details about container configuration, e.g., volumes, GPU and device access,
privileged mode (if used), etc.] While Docker introduces some performance
overhead, it was considered acceptable to ensure a consistent and reproducible
environment for all implementations.

The latest stable releases of the language toolchains were used for all
implementations: Rust #ct[version], C++20 with GCC #ct[version], and Python
#ct[version].

]

#wc[
=== Deterministic Load Generator

To reliably compare the performance of the three implementations, a synthetic
load generator was developed to create reproducible and deterministic simulated
sensor data. This ensures that the behaviour of each implementation can be
compared using the same baseline data, and that differences in performance can
be attributed to the runtime models and backpressure policies, and not input
variability.

The load generator produces three streams of data to shared memory buffers for
consumption by the HAR pipelines: #todo[check how sensors provide data --- may
need harness to connect with API and also copy to shared memory] (1) an RGB
video stream to simulate the camera, (2) a 3-axis inertial measurement stream to
simulate the accelerometer,  and (3) a second 3-axis inertial measurement stream
to simulate the gyroscope.

The unbounded buffer allowed the generator to write data at a consistent rate
without being blocked by the pipeline. Using shared memory allowed for
low-latency communication.

The generated image data was random noise. Each image was created as an array of
RGB pixel values with dimensions of 1920x1080 to match the sensor data, and each
pixel's red, green, and blue values were assigned random whole numbers in the
range $[0,255]$.

To generate the IMU data, mathematical functions were used to create data
similar to that produced by real-world movements (e.g., sine waves to simulate
smooth motion, etc.), while still being deterministic and reproducible.

#todo[Check previous work for synthetic HAR data generation.]

To allow backpressure policies to be evaluated under varying load, the generator
accepts a _load_ parameter that dictates the speed at which data is produced by
acting as a divisor of the baseline sensor intervals. For example, a value of
1.0 produces data at the same rate as the sensors: 30 FPS for the camera (1
frame every 33.3 ms), and 1.6 kHz and 2.0 kHz for the accelerometer and
gyroscope respectively (0.625 ms and 0.5 ms intervals respectively). A value of
2.0 produces data twice as fast, 0.5 produces data at half the speed, and so on.
100% saturation of the pipelines was determined by adjusting the load argument
until the pipelines were consistently backpressured (see @sec-backpressure).

A hard-coded seed for each sensor ($"rgb" = 42, "accel" = 43, "gyro" = 44$) was
used to create three deterministic data-streams to ensure the same generated
data was fed into each implementation. Because the AI inference is only a
repeatable workload to determine the performance of the runtime models, and we
are not concerned about prediction accuracy, the generated data was not designed
to be realistic. This kept the load generator implementation simple, and reduced
latency and overhead that could confound the results.

The load generator was written in Rust, which is a performance-oriented
language, and is memory-safe without a GC that may introduce latency spikes. For
maximum timing accuracy, `nix::time::clock_nanosleep` was used to implement the
timing of the data generation, the generator was pinned to one CPU core to
prevent jitter caused by the overhead of saving and restoring the generator
thread state, and the process was given a real-time scheduling policy.

Before using the load generator, the HAR pipelines were tested with real sensor
data to ensure that they were functionally correct and optimised.
]

#wc[
=== Backpressure Policies <sec-backpressure>

Bounded backpressure policies are implemented in each language-specific runtime
model. In a typical backpressure implementation, when a _consumer_ is saturated
(i.e., the buffer is full), the active backpressure policy is triggered to slow
the flow of data from the _producer_ to prevent unbounded memory demand and
system instability.

The backpressure policies were implemented in the pipelines using two shared
memory buffers per data stream: (1) an unbounded _producer buffer_ in shared
memory for the load generator to write data into, allowing it to produce data at
a consistent rate, and (2) a _consumer buffer_ implemented idiomatically for the
pipelines to read data from for processing, with a fixed #ct[capacity] to
trigger the backpressure policy when full. Backpressure is implemented only in
the pipeline on the consumer buffer, forcing each language runtime model to
handle concurrency, memory allocation, and scheduling within realistic
constraints and allowing us to evaluate RQ2. A _bridge_ in the pipeline is
responsible for copying data from the producer buffer to the consumer buffer,
and for triggering the backpressure policy when the consumer buffer is full.

Each pipeline uses language-specific idiomatic implementations of the
backpressure policies: Rust uses #ct[TODO], C++ #ct[TODO], and Python #ct[TODO].

Four backpressure policies where implemented: (1) _bounded queue_, which blocks
the producer when the buffer is full until space is available, (2)
_drop-oldest_, which drops the oldest data in the buffer to make room for new
data when the buffer is full, (3) _drop-newest_, which drops the newest data
when the buffer is full, and (4) _exponential-back-off_, which waits a short
time before retrying to produce data when the buffer is full, with the wait time
doubling with each retry. #todo[Review literature for common backpressure
policies and confirm these are the most relevant for Edge-AI pipelines.]

#todo[Add detail of how saturation was determined.]
]

#wc[
=== Profiling and Metrics
]

#wc[
=== Statistical Analysis
]
]

= Implementation

#wc[
=== Model Fusion

#todo[
- Two AI models.
- Late fusion.
- Zero On Hold (ZOH) for IMU data.
- Sensor data interpolation not used to simulate data between sensor updates,
  removing number precision as a confounder.
]
]

= Results

= Discussion

= Conclusion

Total words: #total-words

#colbreak()
#set par(justify: false)
#bibliography("refs.bib", title: "References", style: "ieee")
]
