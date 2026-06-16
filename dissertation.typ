#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import fletcher.shapes: cylinder, rect
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

#let red = rgb("F8D7DA")
#let blue = rgb("CCE5FF")
#let pale_blue = rgb("#EBF4FF")
#let green = rgb("D4EDDA")
#let pale_green = rgb("#EDF8EF")
#let cream = rgb("FFFBEB")
#let pale_cream = rgb("#FFFEF9")
#let grey = luma(150)
#let charcoal = rgb("#2D3748")

#let wc(body) = word-count(total => [
  #body
  #set text(size: 0.8em, style: "italic")
  // #align(right)[#{total.words - 1}]
])

// #set text(size: 12pt)
#columns(2, gutter: 16pt)[
#wc[
= Introduction

== Background and Context

#wc[
In recent years, Edge-AI (Edge Artificial Intelligence) has begun to move the
deployment of AI models from centralised cloud-based servers to local devices,
such as sensors, mobile phones, and embedded systems. This decentralisation of
AI processing offers several advantages over traditional cloud computing: (1) it
enables _real-time processing_ by removing network latency, which is essential
for time-sensitive applications such as autonomous vehicles and industrial
automation; (2) it drastically _reduces internet bandwidth usage_, allowing
systems to operate in environments where connectivity is unreliable or
unavailable, such as remote weather stations or satellite image analysis; (3) it
enhances _privacy and security_ by ensuring that sensitive information, such as
healthcare monitoring or smart home video feeds, is processed locally and not
transmitted across the internet; and (4) by removing the need for continuous
data transmission, Edge-AI can improve overall _energy efficiency_ in
battery-powered IoT deployments. These advantages are driving the expansion of
large-scale Edge-AI projects, such as in smart city infrastructure, where
Edge-AI is increasingly deployed directly into municipal infrastructure to
improve efficiency and sustainability, such as in the control of "smart" traffic
lights or street lighting.

While recent advancements in heterogeneous System-on-Chips (SoCs) have made
Edge-AI deployments practical by integrating dedicated AI accelerators into
small form factors, these devices do bring challenges in terms of resource
constraints, such as limited memory, power consumption, and thermal limits.
Furthermore, remote software updates to maintain Edge-AI applications also come
at a cost, as they can be expensive and time-consuming, especially when dealing
with a large number of devices. Because the software must make maximum use of
the limited hardware resources, while also remaining stable over the long term,
programming language selection is an important design decision for Edge-AI
pipelines.
]

== Problem Statement

#wc[
When deploying on Edge hardware, the aforementioned challenges amplify the impact of
programming language choice. A language's runtime model dictates memory management,
concurrency, and scheduling behaviour under load, which directly impacts
latency, throughput, and resource usage. For example, manual memory management
offers fine-grained control and increased performance, but simultaneously
increases the risk of memory leaks and undefined behaviour. Conversely, memory
management may be automated through garbage collection (GC) at the cost of
increased latency and unpredictable latency jitter.

This dissertation focuses on the performance metrics at the system level.
_Latency_ does not refer to network transmission time, but rather the processing
time from when the sensor data is created to when the final AI prediction is
completed. This included queueing delays, inference time, and final fusion of
the prediction. _Throughput_ measures how many sensor events the pipeline can
process per unit of time (e.g. per second) when under sustained load.

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

  + *Runtime Performance:* How do the runtime models /*(memory and
    concurrency)*/ of Rust/*(borrow checker/async runtimes)*/, C++/*(manual
    memory management/native threads)*/, and Python /*(GC/GIL)*/ influence
    latency/*(p50/p95/p99)*/, throughput, and memory consumption in a tri-stream
    HAR pipeline on Edge-AI hardware?
    /* #todo[runtime models and latency percentiles might belong in the
    methodology section] */

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

  + Analyse runtime model overhead to explain performance differences, and
    derive empirically grounded guidance for language selection in constrained
    Edge-AI deployments. /*#todo[allocation churn, GC pause duration, async
    task-switch overhead belong in the methodology section]*/
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

The pipeline architecture, deterministic load generator, backpressure, and
telemetry mechanisms are designed for portability across Linux environments.
However, AI acceleration, thermal behaviour, and power management are
fundamentally SoC-dependent. Consequently, the profiling and acceleration tools
used during evaluation (e.g. NVIDIA tegrastats, TensorRT) are specific to the
Jetson Orin Nano platform and cannot be directly applied across other edge
devices.

A further limitation of this study is that it is not concerned with the accuracy
of the HAR prediction results. To ensure the data is both deterministic and
reproducible for each implementation, a synthetic load generator is used.
Pre-recorded data is not used to avoid confounding the results with disk I/O
bottlenecks, ensuring the data is available to the pipeline at a consistent
rate. It is acknowledged that the choice of load shedding policy would impact
prediction accuracy and usefulness of the results, due to the dropping of data
and temporal discontinuity. However, this dissertation is strictly concerned
with performance measurements of latency, throughput, and memory efficiency at
the system level, and not the accuracy of the HAR model itself.
]


== Dissertation Outline

#wc[
The remainder of this dissertation is structured as follows: #box[*Chapter 2*]
provides background on the evolution of Edge-AI and the heterogeneous devices
employed. It also introduces the programming languages evaluated in this
dissertation, and briefly explains the concepts of backpressure and load
shedding. #box[*Chapter 3*] reviews related literature regarding language
efficiency benchmarks and the trade-offs between memory safety and cognitive
load, concluding by identifying the research gap.
#box[*Chapter 4*] details the methodology, including the
hardware and software setup, backpressure interfaces, and profiling toolchains
used to collect metrics. #box[*Chapter 5*] describes the implementation of the HAR
pipeline in each language, highlighting language-specific optimisations and
challenges. #box[*Chapter 6*] presents the results, including performance
metrics, memory allocation and GC pressure, and backpressure outcomes under
varying loads. #box[*Chapter 7*] discusses the findings and limitations of the
study. Finally, #box[*Chapter 8*] concludes by addressing the research
questions, providing practical recommendations for language selection in Edge-AI
contexts, and suggesting directions for future work.
]
]

#wc[
= Background

#wc[
== The Evolution of Edge Computing

The late 1990s saw a growth of online multimedia that demanded a solution to
tackle increased network congestion and latency. Karger et al. (1997)
@karger1997 proposed a concept of _distributed caching protocols_ that evolved
into modern-day _Content Delivery Networks_ (CDNs), ensuring that static content
could be cached on servers located closer to end-users, thus reducing latency
and bandwidth usage, especially during periods of high demand.

\2007 saw the release of the iPhone, followed by the Android operating system in
\2008. These marked a rapid increase in the use of mobile devices, and created
user demand for computationally intensive applications. However, as
Satyanarayanan et al. (2009) @satyanarayanan2009 established, "considerations
such as weight, size, battery life, ergonomics, and heat dissipation exact a
severe penalty in computational resources such as processor speed, memory size,
and disk capacity." To bypass these physical limitations, they took the concept
of CDNs further by introducing decentralised and widely dispersed _cloudlets_
--- servers located on the network edge and close to end-clients (e.g. in cafe
premises) that run customised service software using hardware VM technology,
thus allowing mobile devices to act as thin clients, overcoming hardware
constraints without unacceptable latency and bandwidth usage that would be
introduced if remote cloud servers were used.

The next decade saw an explosive growth of the Internet of Things (IoT), fuelled
by the adoption in areas such as Fitness Wearables (the first Fitbit Tracker
launched in \2009), Smart Home devices (Google acquired Nest Labs in \2014, and
Amazon acquired Ring LLC in \2018), and "dockless" bicycle-sharing schemes (Lime
launched in \2017). Remote devices were no longer just data consumers, but had
also become data producers. Shi et al. (2016) @shi2016 defined "edge" not as a
specific device, but as any computing and networking resource along the path
between the data source and the data centre. They recognised that the data
bandwidth and centralised processing in traditional cloud computing were
bottlenecks, arguing that data should be processed or massaged at the proximity
of the data source.

At the same time, the integration of AI rapidly accelerated. While some
applications were designed to run on remote cloud servers (e.g. ChatGPT,
launched in late \2022), latency-critical applications depended on local-device
processing to ensure safety and reduce dependence on available network bandwidth
(e.g. Tesla Autopilot, launched in \2014, and the Waymo One in \2018).

This transition to _Edge-AI_ required overcoming the hardware obstacles
identified by Satyanarayanan et al. and the network bottlenecks identified by
Shi et al. Zhou et al. (2019) @zhou2019 provided a comprehensive survey of
recent research efforts in Edge Intelligence, and identified that physical
proximity to the data source is critical to reducing monetary costs, latency,
and the risk of privacy leakage. For evaluating the quality of Edge-AI
inference, they highlighted latency, accuracy, energy consumption, privacy, and
memory footprint. While communication overhead is eliminated by offline edge
processing, the remaining metrics remain relevant to this dissertation. For
example, backpressure policies may intentionally drop data to ensure system
stability, sacrificing model accuracy to satisfy strict latency deadlines.
]

#wc[
== Heterogeneous Devices and DVFS

Heterogeneous devices combine different types of processing units, such as a CPU
and a GPU, onto a single chip and are an increasingly common solution for
Edge-AI deployments. Modern heterogeneous System-on-Chips (SoCs), such as the
NVIDIA Jetson Orin Nano, integrate dedicated CUDA cores for general-purpose GPU
computing, and Tensor cores for AI acceleration. These allow optimised engines
like TensorRT to efficiently execute AI pipelines, such as HAR, locally without
depending on remote cloud servers. Furthermore, they support the enabling
technologies identified by Zhou et al., such as model compression (e.g.
quantisation and pruning), to maximise inference speed.

However, embedded devices with a small form factor generate significant heat
when under sustained heavy load such as that generated by Edge-AI pipelines. To
prevent hardware failure, the Jetson Orin Nano relies on _Dynamic Voltage and
Frequency Scaling_ (DVFS) to reactively throttle the CPU and GPU speeds when
thermal limits are reached. Peluso et al. (2019) @peluso2019 demonstrated that
this introduces non-deterministic pipeline performance degradation. To minimise
premature throttling, the software architecture and language runtime model must
be efficient by minimising unnecessary CPU and memory overhead.
]

#wc[
== AI Acceleration

*CUDA* (Compute Unified Device Architecture) @cuda provides a parallel execution
environment and programming model for heterogeneous computing systems with
NVIDIA GPUs, using a Single Instruction Multiple Threads (SIMT) architecture. In
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
common deep learning operations (e.g. normalisation, matrix multiplication,
softmax, etc.).

*TensorRT* @tensorRT is responsible for compiling an *ONNX* (Open Neural Network
Exchange) @onnx model into a _.engine_ file, optimised to run on the Jetson GPU.

All implementations interact with the *ONNX Runtime* to load and execute the AI
model, which is responsible for the data transfer and inference orchestration on
the host, and hands off responsibility to TensorRT for inference execution on
the device. To ensure a consistent baseline, the same optimised _.engine_ file
was used across all three implementations.
]

#wc[
== Language Runtimes & Memory Models

To mitigate the thermal throttling inherent in Edge-AI hardware, the pipeline
implementation must be highly efficient. This dissertation compares the impact
of three language runtime models on Edge-AI performance: C++, Rust, and Python.

C++ is an Ahead-of-Time (AOT) compiled (i.e. compiled to native machine code
before execution) general-purpose language, designed for high performance and
efficiency. It provides manual memory management, allowing fine-grained control
over usage. However, this introduces risks of severe memory-safety bugs such as
double-free and use-after-free, which can lead to undefined behaviour and
security vulnerabilities.

Rust is similarly an AOT compiled general-purpose language. In addition to high
performance and efficiency, it also provides memory safety. Rust achieves this
by employing Ownership Based Resource Management (OBRM, more commonly referred
to as its ownership and borrowing model) which provides compile-time guarantees
of memory safety --- every value has a single owner, and the compiler ensures
that value references do not outlive their owners. This provides a strong
guarantee of memory correctness, but increases cognitive load as the OBRM is a
novel concept that introduces a steep learning curve.

Python is a general-purpose language that is compiled to bytecode and
interpreted at runtime. It emphasises simplicity and ease of both writing and
reading. CPython (the reference implementation) has a Foreign Function Interface
(FFI) that allows it to interface with other languages, such as C/C++ libraries.
Python is often used to automate tasks and for data analysis and machine
learning. It utilises a GC, abstracting memory management to reduce cognitive
load and the risk of memory-safety bugs, but at the cost of increased latency
and unpredictable latency jitter due to "stop-the-world" GC events. Latency is
further impacted by the Global Interpreter Lock (GIL), which prevents true
concurrency across multiple CPU cores.
]

#wc[
== Stream Processing & Backpressure

In stream processing systems, such as HAR pipelines, data is generated
continuously and must be processed in real-time. When the rate of generation
exceeds the system's processing capacity, backpressure builds up within the
pipeline as the number of unprocessed data items increases. This can lead to
memory exhaustion and system instability if not managed effectively.

However, because the pipeline cannot request the sensors to slow down their rate
of transmission, traditional backpressure mechanisms are impossible. Instead,
_load shedding_ policies are necessary. Policies such as dropping data (e.g.
dropping the oldest or newest events) or limiting the rate of data production
(e.g., adaptive decimation, which queues only every $n$-th event when under
load) are commonly used to manage backpressure, but introduce an accuracy
trade-off as data is lost.
]
]

#wc[
= Literature Review

#wc[
== Benchmarking Language Efficiency

Empirical evaluations of programming languages highlight a trade-off between
execution speed, energy consumption, and memory footprint. In a comprehensive
study of \27 programming languages, Pereira et al. (2017) @pereira2017energy
showed that compiled languages typically  were the most performant, needed less
memory, and were more energy efficient. Conversely, interpreted languages
required the most memory, consumed the most energy, and were the slowest.

However, the reported results also indicated that execution speed and energy
efficiency do not perfectly correlate with memory efficiency. For example, in
the normalised results, Rust performed second only to C in terms of energy
efficiency (1.03) and execution speed (1.04), but seventh (1.54) in terms of
memory usage.
]

#wc[
== Memory Safety vs. Cognitive Load Trade-off

While languages like C++ offer high performance, their reliance on manual memory
management introduces severe security vulnerabilities. The scale of this risk is
reflected in the 2025 Common Weakness Enumeration (CWE) Top \25 Most Dangerous
Software Weaknesses @mitre2025cwe, where memory-safety flaws such as
out-of-bounds writes accounted for seven (28%) of the top \25 exploits.

To address this, Rust's OBRM provides compile-time guarantees of memory safety
without a GC. Xu et al. (2021) @xu2021memory analysed \186 real-world bug
reports in Rust projects to determine how effectively OBRM prevents
memory-safety bugs in practice. They found that all memory-safety bugs in the
dataset, except one that was a compiler bug, were caused by developers using the
`unsafe` keyword to bypass the compiler's memory safety checks. However, while
Coblenz et al. (2023) @coblenz2023 found that developers generally understood
the concept of ownership, they struggled with the semantics of references and
borrowing. This introduces a trade-off between memory safety and developer
cognitive load.
]

#wc[
== The Research Gap

While studies such as Pereira et al. (2017) @pereira2017energy have evaluated
language efficiency, these benchmarks are typically conducted on standard
desktop-class hardware. In contrast, studies that have evaluated the performance
of Edge-AI pipelines @zhou2019 @peluso2019 have focused on the AI models
themselves, ignoring how the host programming language impacts performance
through its memory churn, GC pauses, and concurrency overhead.

At the time of the study conducted by Pereira et al., Rust's default memory
allocator on some platforms (including the system used by Pereira et al.) was
`jemalloc` @evans2006jemalloc, which is designed for fast concurrent execution
on multi-processor systems by maintaining multiple memory arenas. However, the
Core Rust team acknowledged several drawbacks of using `jemalloc` @rustRfc1974,
including adding \~300KB to binary sizes. RFC \1974 allowed users to change the
global allocator, and in \2019 Rust 1.32.0 @rust1320 changed from `jemalloc` to
the standard system allocator. This necessitates a re-evaluation of Rust's
memory footprint, as the change in allocator may have impacted its memory and
performance efficiency.

Therefore, there is a research gap in empirically evaluating how the Rust, C++,
and Python runtime models interact with backpressure policies under the thermal
constraints of Edge-AI devices with continuous streams of sensor data.
Consequently, an evaluation of their runtime performance under heavy load is
necessary to determine their suitability for Edge-AI pipelines.
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
carrier board with I/O interfaces (e.g. USB, Ethernet, DisplayPort), a MicroSD
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

The Jetson was flashed with NVIDIA's JetPack 6.2.2 SDK @jetpack-6-2-2, which
includes Jetson Linux 36.5 (featuring the Linux Kernel 5.15 and an Ubuntu
22.04-based root file system), and CUDA 12.6, cuDNN 9.3, and TensorRT 10.3 for
AI inference and acceleration. The software stack versions were selected as the
most recent stable releases at the time of development, and were used for all
implementations to ensure a consistent baseline for comparison. #todo[Add ONNX
version and Python variant details.]

Performance and overhead of the language runtime models was measured at the
boundary of the host/device memory separation, where the CPU manages the runtime
model, and the SIMT architecture runs the AI workloads on the GPU. This prevents
confounding the results with hardware latency, and provides a clearer comparison
of how each language's runtime model performs under load and backpressure.

A Docker container, based on NVIDIA's official _l4t-base_ image (#ct[version]),
was used to prevent host updates to ensure that the software toolchains and
environment variables remained consistent for all implementations. #todo[Add
details about container configuration, e.g. volumes, GPU and device access,
privileged mode (if used), etc.] While Docker introduces some performance
overhead, it was considered acceptable to ensure a consistent and reproducible
environment for all implementations.

The latest stable releases of the language toolchains were used for all
implementations: Rust #ct[version], C++20 with GCC #ct[version], and Python
#ct[version].
]

#wc[
=== Deterministic Load Generator

To reliably compare the performance of the three implementations, a separate synthetic
load generator, shown in @fig:architecture, was developed to create reproducible and deterministic simulated
sensor data. This ensures that the behaviour of each implementation can be
compared using the same baseline data, and that differences in performance can
be attributed to the runtime models and backpressure policies, and not input
variability.

#figure(
  scope: "parent",
  placement: bottom,
  
  pad(top: 1.5em)[
    #set text(size: 8pt)

    #let n(x, t, f, s) = node((x,1), align(center)[#t], fill: f, shape: s)
    #let r(x, t) = n(x, t, pale_green, rect)
    #let c(x, t) = n(x, t, pale_blue, cylinder)
    #let e(x, y, t) = edge((x,1), (y,1), "-|>", mark-scale: 175%,
      label: align(center)[#t], label-side: left)

    #diagram(
      node-stroke: 0.5pt + charcoal,
      node-corner-radius: 2pt,
      node-inset: 6pt,
      spacing: (45pt, 12pt),

      node((3,0), align(center)[*HAR Pipeline*], stroke: none),
      node(
        enclose: ((2,1), (4,1)), 
        stroke: (paint: charcoal, dash: "dashed", thickness: 1pt), 
        inset: 12pt
      ),

      r(0, [Load Generator\ (Rust)]),
      c(1, [Unbounded Buffer\ (Shared Memory)]),
      r(2, [Language Bridge\ (C++/Rust/Py)]),
      c(3, [Bounded Buffer\ (Idiomatic)]),
      r(4, [AI Inference\ (TensorRT)]),

      e(0, 1, [Push]),
      e(1, 2, [Poll]),
      e(2, 3, [Push/Drop]),
      e(3, 4, [Dequeue]),
    )
  ],

  caption: [System architecture demonstrating communication between the separate
    Load Generator and the HAR Pipeline implementations.],
) <fig:architecture>

The load generator produces three streams of data to shared memory buffers for
consumption by the HAR pipelines: (1) an RGB video stream to simulate the
camera, (2) a 3-axis inertial measurement stream to simulate the accelerometer,
and (3) a 3-axis inertial measurement stream to simulate the gyroscope. Using
shared memory allowed for low-latency communication, and allowed the generator
to write data at a consistent rate without being blocked by the pipeline.

The generated image data was random noise. Each image was created as an array of
RGB pixel values with dimensions of 1920x1080 to match the sensor data, and each
pixel's red, green, and blue values were assigned random whole numbers in the
range $[0,255]$. Similarly, the generated IMU data was random floating-point
numbers within the maximum hardware ranges of the BMI088 sensor
(#sym.plus.minus\24g for acceleration and #sym.plus.minus\2000#sym.degree/s for
angular rate).

A hard-coded seed for each sensor ($"rgb" = 42, "accel" = 43, "gyro" = 44$) was
used to create the three deterministic data-streams to ensure the same generated
data was fed into each implementation. Because the AI inference is only a
repeatable workload to determine the performance of the runtime models, and
prediction accuracy does not impact the evaluation, the generated data was not
designed to be realistic. This kept the load generator implementation simple,
does not introduce disk I/O bottlenecks, and reduced latency and overhead that
could confound the results by stealing CPU cycles or memory bandwidth from the
pipelines.

To allow backpressure policies to be evaluated under varying load, the generator
accepts a _load_ parameter that dictates the speed at which data is produced by
acting as a multiplier of the baseline sensor intervals. This multiplier is
applied equally to all three data streams to ensure the ratio between the camera
and the IMU data remains consistent. For example, a value of \1.0 produces data
at the same rate as the sensors: \30 FPS for the camera (\1 frame every \33.3
ms), and \1.6 kHz and \2.0 kHz for the accelerometer and gyroscope respectively
(\0.625 ms and \0.5 ms intervals respectively). A value of \2.0 produces data
twice as fast, \0.5 produces data at half the speed, and so on. 100% saturation
of the pipelines was determined by adjusting the load argument until the
pipelines were consistently backpressured (see @sec-backpressure).

The load generator was written in Rust to take advantage of its performance and
memory safety guarantees. For maximum timing accuracy,
`nix::time::clock_nanosleep` was used to implement the timing of the data
generation, the generator was pinned to one CPU core to prevent jitter caused by
the overhead of saving and restoring the generator thread state, and the process
was given a real-time scheduling policy.

Before using the load generator, the HAR pipelines were tested with real sensor
data to ensure that they were functionally correct and optimised. A lightweight
harness was developed to read data from the sensors, and write to the same
shared memory buffers. This decoupling ensures the same pipeline code is
executed during both the functional testing and the performance evaluations,
without modifying the pipelines or using conditional logic to change the path of
execution.
]

#wc[
=== Backpressure Policies <sec-backpressure>

Bounded backpressure policies are implemented in each language-specific runtime
model. In a typical backpressure implementation, when a _consumer_ is saturated
(i.e. the buffer is full), the active backpressure policy is triggered to slow
the flow of data from the _producer_ to prevent unbounded memory demand and
system instability.

The backpressure policies were implemented in the pipelines using two buffers
per data stream: (1) an unbounded _producer buffer_ in shared memory for the
load generator to write data into, allowing it to produce data at a consistent
rate, and (2) a _consumer buffer_ implemented idiomatically for the pipelines to
read data from for processing, with a fixed #ct[capacity] to trigger the
backpressure policy when full. Backpressure is implemented only in the pipeline
on the consumer buffer, forcing each language runtime model to handle
concurrency, memory allocation, and scheduling within realistic constraints and
allowing us to evaluate RQ2. A _bridge_ in the pipeline is responsible for
copying data from the producer buffer to the consumer buffer, and for triggering
the backpressure policy when the consumer buffer is full.

Each bridge uses language-specific idiomatic implementations of the backpressure
policies: Rust uses #ct[TODO], C++ #ct[TODO], and Python #ct[TODO].

Five backpressure and load shedding policies were implemented to manage queue
saturation when the consumer buffer is full:

*Policies that attempt to preserve all data (Flow Control):*
  - *Bounded queue:* Blocks the producer until space is available in the
    consumer buffer.
  - *Exponential-backoff:* Waits a short time before retrying to insert the
    data, with the wait time doubling with each retry.

*Policies that intentionally drop data (Load Shedding):*
  - *Drop-oldest:* Drops the oldest data in the consumer buffer to make room for
    new data.
  - *Drop-newest:* Drops incoming data when the buffer is full.

*Policies that drop data while preserving temporal continuity:*
  - *Adaptive decimation:* Dynamically downsamples the data stream (i.e.,
    queueing only every _nth_ event) to reduce pressure on the consumer buffer
    while preserving the temporal continuity of the data.

Bounded queue and exponential backoff are both flow control policies, and
instead of dropping data they stall the data producer when the consumer buffer
is full. However, this can lead to unbounded memory growth of the producer
buffer, causing system instability. Conversely, drop-oldest, drop-newest, and
adaptive decimation are all load shedding policies that discard data, as
visualised in @fig:load_shedding, though this does lead to a loss of temporal
continuity and may impact prediction accuracy.

#figure(
  align(center)[
    #let packet(n, c) = box(width: 1.2em, height: 1.2em, stroke: 0.5pt + grey,
      fill: c, radius: 2pt, align(center+horizon)[#n])
    #let k(n) = packet(n, green)
    #let d(n) = packet(n, red)

    #pad(top: 1em, bottom: 0.75em)[
      #grid(
        columns: (100pt, auto),
        align: (right + horizon, left + horizon),
        row-gutter: 1.5em,
        column-gutter: 1.5em,

        [*Incoming Stream:* \ _(Events 1 to 6)_],
        stack(dir: ltr, spacing: 6pt, k(1), k(2), k(3), k(4), k(5), k(6)),

        [*Drop-Newest:* \ _(Queue full at 4 events)_],
        stack(dir: ltr, spacing: 6pt, k(1), k(2), k(3), k(4), d(5), d(6)),

        [*Drop-Oldest:* \ _(Queue full at 4 events)_],
        stack(dir: ltr, spacing: 6pt, d(1), d(2), k(3), k(4), k(5), k(6)),

        [*Adaptive Decimation:* \ _(Queueing every 2nd event)_],
        stack(dir: ltr, spacing: 6pt, k(1), d(2), k(3), d(4), k(5), d(6)),
      )
    ]
  ],

  caption: [Load shedding policies on a stream of sensor events. Green blocks
    represent preserved data, red blocks represent dropped data. #v(1em)],
) <fig:load_shedding>

To ensure the runtime models were evaluated under sustained stress, the
saturation threshold was determined by increasing the _load_ multiplier until at
least one consumer buffer reached capacity, ensuring the backpressure mechanism
was continuously engaged across all policies. Because the languages differ in
performance, a single, separate load multiplier was determined for each
language. This ensured that all policies were evaluated using identical rates of
ingestion for each runtime model, isolating the behaviours of the runtime models
and removing execution speed as a confounding variable. ]

#wc[
=== Profiling and Metrics

==== Latency

To measure latency of the pipelines, the `CLOCK_MONOTONIC_RAW` clock was used to
capture timestamps at key points as the data events flowed through the pipeline.
This provides high-resolution timing information that is not affected by system
time changes or adjustments. The following six timestamps, as visualised in @fig:latency_timeline, were captured for each
event:

+ `t_generated` when the generator pushes to the unbounded buffer
+ `t_bridged` when the bridge pushes to the idiomatic buffer
+ `t_pipeline_in` when the pipeline pulls the event from the idiomatic buffer
+ `t_pipeline_out` when the pipeline pushes data to the ONNX Runtime for
  inference
+ `t_fusion_in` when inference completes and the pipeline begins late fusion
+ `t_fusion_out` when late fusion completes and the pipeline produces the
  final output

#figure(
  placement: top,
  scope: "parent",

  // pad(top: 1em, bottom: 0.5em)[
  pad(bottom: 1em)[
    #let n(x, t) = node((x,0), t)
    #let e(x, y, t, s, ls) = edge((x,0), (y,0), "|-|", align(center)[#t],
      shift: s, label-sep: 0.25em, label-side: ls)
    #let te(x, y, t) = e(x, y, t, 25pt, left)
    #let be(x, y, t) = e(x, y, t, -25pt, right)

    #diagram(
      node-stroke: 0.5pt + charcoal,
      node-fill: pale_cream,
      node-corner-radius: 1.5pt,
      node-inset: 5pt,
      spacing: 28pt,

      e(0, 5, [*Total System Latency*], 60pt, left),
      edge((0,0), (5,0), "-", stroke: 1pt + charcoal),

      n(0, [`t_generated`]),
      n(1, [`t_bridged`]),
      n(2, [`t_pipeline_in`]),
      n(3, [`t_pipeline_out`]),
      n(4, [`t_fusion_in`]),
      n(5, [`t_fusion_out`]),

      be(0, 1, [Unbounded\ Queue Wait]),
      te(1, 2, [Idiomatic\ Queue Wait]),
      be(2, 3, [Data\ Preparation]),
      te(3, 4, [Inference]),
      be(4, 5, [Fusion\ Logic]),
    )
  ],

  caption: [Timeline of the six timestamps captured for each event as it flows
    through the pipeline. #v(0.25em)]
) <fig:latency_timeline>

Coordinated Omission occurs when a stalled system fails to record the true
extent of tail-latency delays by omitting the time that the event truly occurred
@howNotToMeasureLatency. By decoupling the load generator from the pipelines and
ensuring that it pushes to an unbounded buffer, it is never blocked when the
System Under Test (SUT) is stalled, thus ensuring that `t_generated` allows
latency delays to be accurately captured.

These timestamps provide five key latency measurements: _Unbounded Queue Wait_
($"t_bridged" - "t_generated"$), _Idiomatic Queue Wait_ ($"t_pipeline_in" -
"t_bridged"$), _Data Preparation_ ($"t_pipeline_out" - "t_pipeline_in"$),
_Inference_ ($"t_fusion_in" - "t_pipeline_out"$), and _Fusion_ ($"t_fusion_out"
- "t_fusion_in"$). Additionally, _Total System Latency_ ($"t_fusion_out" -
"t_generated"$) was calculated to capture the end-to-end processing time.

These measurements provide the necessary granularity to measure each runtime
model's latency, and to identify bottlenecks and trade-offs under load and
backpressure.

High Dynamic Range (HDR) Histograms @hdrhistogram were used to aggregate the
latency distributions, preventing memory allocation from polluting the latency
measurements that would occur if the measurements were stored in standard data
structures (e.g. vectors or lists).

To retain temporal information about how latency changes over time and
correlates with runtime model behaviour and backpressure events, a
double-buffering approach was used. Using HdrHistogram's `WriterReaderPhaser`
class ensured the pipeline (the _writer_) thread could write measurements to an
active histogram without blocking (i.e. is wait-free @herlihy1991wait).
Concurrently, a lightweight background telemetry thread (the _reader_)
periodically rotated the buffers, extracting the throughput alongside the
$"p50"$, $"p95"$, $"p99"$, $"p99.9"$, $"p99.99"$, and maximum latency values
from the newly inactive histogram into a pre-allocated fixed-size array at
#ct[fixed intervals], without any blocking of the pipeline thread.

#figure(
  pad(top: 0.5em)[
    #set text(size: 8pt)
    
    #let n(x, y, t, f, s) = node((x,y), align(center)[#t], fill: f, shape: s)
    #let r(x, y, t) = n(x, y, t, pale_green, rect)
    #let c(x, y, t) = n(x, y, t, pale_blue, cylinder)
    #let e(p1, p2, t, ls) = edge(p1, p2, "-|>", mark-scale: 175%,
      label: align(center)[#t], label-side: ls)

    #diagram(
      node-stroke: 0.5pt + charcoal,
      node-corner-radius: 2pt,
      node-inset: 8pt,
      spacing: (70pt, 60pt),

      r(0, 0, [Pipeline Thread\ (Writer)]),
      r(1, 0, [Telemetry Thread\ (Reader)]),

      c(0, 1, [Active\ HDR Histogram]),
      c(1, 1, [Inactive\ HDR Histogram]),

      e((0,0), (0,1), [Record Latency\ (Wait-Free)], center),
      e((1,0), (1,1), [Extract p99 & Max\ (Locks Reader Only)], center),

      edge((0,1), (1,1), "<|--|>", mark-scale: 175%,
        label: align(center)[Atomic Swap\ (1 Hz Interval)], label-side: right)
    )
  ],

  caption: [Double-buffering approach to atomically capture the telemetry
    without\ blocking the pipeline thread.]
) <fig:double_buffering>

==== Memory Churn (C++ and Rust)

To measure the rate of memory churn in C++ and Rust (RQ3), the global memory
allocation and deallocation functions were overridden to capture memory
allocation metrics, without relying on third-party profiling tools that may
introduce additional overhead and confound the results. In C++, the
`operator new` and `operator delete` functions were overridden, and in Rust a
custom memory allocator was implemented as the standard library's default by
using the `#[global_allocator]` attribute.

The telemetry thread concurrently captured the memory allocation metrics during
the same intervals as the latency measurements, allowing for correlation between
memory churn under load and backpressure events.

Read-tears occur when the telemetry thread reads the allocation metrics out of
sync with the pipeline's updates, which would significantly skew results when
handling large memory allocations, such as the RGB data stream. 

To prevent this, 128-bit atomic operations (`std::atomic` in C++, and
`AtomicU128` in Rust) were utilised. These operations are guaranteed to be
executed as a single, indivisible hardware instruction, which is lock-free on
the Jetson Orin Nano's Cortex-A78AE processor via the ARMv8.2-A architecture's
`FEAT_LSE` (Large System Extensions) feature which was introduced in ARMv8.1
@arm8_1. The allocation count and total bytes allocated were packed into a
single 16-byte aligned structure to be read atomically by the telemetry thread.

To ensure this hardware-level atomicity was enabled, the
#box[`-march=armv8.2-a+lse`] flag was added to the compilation of the C++
implementation, and #box[`-C target-cpu=cortex-a78`] for the Rust
implementation.

==== GC Pressure (Python)

Python uses a Garbage Collector (GC) to manage memory, which can introduce
non-deterministic tail-latency GC pauses (also known as "stop-the-world" events)
when run. Using `tracemalloc` from the standard library would introduce
additional overhead and confound the results, as it introduces tracing for every
memory allocation event. Instead, the GC's built-in `callbacks` hook was
utilised to capture the start and end time of each GC event (using
`CLOCK_MONOTONIC_RAW`) to calculate the duration of each pause.

To prevent memory allocation within the callback function, a double-buffering
HDR Histogram approach was used, similar to the latency measurements, where the
callback function writes the GC pause durations to an active histogram without
blocking. The background telemetry thread then extracts the GC pause percentiles
and maximums at the same time as the latency measurements, allowing correlation
between GC pause durations and runtime model events. 

The telemetry thread also employs `gc.get_stats()` to capture the cumulative
number of objects collected since the Python interpreter was started, from which
the rate of object collection across Generations 0, 1, and 2 can be calculated
using a delta between intervals. This function does not include objects that are
deallocated immediately using Python's main reference counting mechanism, but it
does provide the data to correlate deep Generation 2 collection events with
tail-latency pauses.

==== Memory Fragmentation

Repeated allocation and deallocation of memory can lead to fragmentation, where
free memory is only available in small, non-contiguous blocks. As shown in @fig:memory_fragmentation, this can cause
memory to be exhausted even when the total free memory is sufficient, as
contiguous blocks larger than the fragmented sizes are not available, leading to
Out-Of-Memory (OOM) errors.

#figure(
  align(center)[
    #let block(c) = box(width: 0.75em, height: 0.75em, stroke: 0.5pt + grey,
      fill: c, radius: 2pt)
    #let a = block.with(blue)
    #let f = block.with(cream)
    #let n = block.with(red)

    #pad(top: 1em, bottom: 0.75em)[
      #grid(
        columns: (100pt, auto),
        align: (right + horizon, left + horizon),
        row-gutter: 1.5em,
        column-gutter: 1.5em,

        [*1. Initial State:* \ _(8 blocks allocated)_],
        stack(dir: ltr, spacing: 4pt, a(), a(), a(), a(), a(), a(), a(), a()),

        [*2. Objects Freed:* \ _(4 blocks free)_],
        stack(dir: ltr, spacing: 4pt, a(), f(), f(), a(), a(), f(), f(), a()),

        [*3. New Allocation:* \ _(3 blocks needed)_],
        stack(dir: ltr, spacing: 4pt, a(), f(), f(), a(), a(), f(), f(), a(),
          n(), n(), n()),
      )
    ]
  ],

  caption: [Visualisation of memory fragmentation. Though the total free memory
    (4 blocks) is sufficient for the new allocation (3 blocks), the allocator
    must expand the heap due to the lack of contiguous space, increasing the
    Resident Set Size (RSS). #v(1em)],
) <fig:memory_fragmentation>

To ensure a fair comparison, all three implementations use the Linux interface
`/proc/self/statm` to capture the Resident Set Size (RSS) from the background
telemetry thread. The RSS provides the total amount of memory currently
allocated to the process, including fragmented memory and that allocated by
third-party libraries (e.g. ONNX Runtime). A warm-up period of #ct[TODO]
synthetic events was used at the start of each test to allow the memory usage to
stabilise before the metrics were captured, preventing the initial allocation
and lazy initialisation from skewing the results.

In addition, the C++ and Rust implementations used `mallinfo2()` to capture the
`fordblks` field, which provides the total size of memory allocated by the
process that is currently free, providing insight into the amount of fragmented
memory that is allocated but not currently in use.

==== Thermal and Power Throttling

The Jetson Orin Nano utilises reactive software thermal management (Dynamic
Voltage and Frequency Scaling, or DVFS @jetsonLinuxDeveloperGuide) that
constantly polls the temperature and throttles the performance of the high-power
components (e.g. CPU and GPU) when the device exceeds operating temperature
threshold @thermalGuide. While this prevents thermal shutdowns during normal
operation, it introduces a confounder when comparing the performance of
different runtime model implementations.

To mitigate this the device was allowed to cool down between tests #todo[needs
quantified] to ensure that initial thermal conditions were consistent across all
implementations. Temperatures during testing were measured using the
`tegrastats` utility, which provides monitoring of the CPU, GPU, and overall
temperatures, CPU and GPU frequencies, and power consumption. This allows us to
analyse the impact of the different runtime models on thermal behaviour, and to
correlate throttling events with performance metrics.
]

#wc[
=== Statistical Analysis

Latency measurements have no theoretical maximum, but are inherently bounded by
a minimum value of zero. This typically results in non-normal distributions
which are heavily skewed to the right, with long tails and outliers
@howNotToMeasureLatency, requiring non-parametric methods for statistical
analysis. Data cleaning was restricted to only removing the first #ct[TODO]
events to allow for warm-up and system stabilisation. The outliers are evidence
of backpressure events and runtime model pauses (e.g. Garbage Collection in
Python), necessary for benchmarking and implementation comparisons, and
consequently were not removed.

The mean is sensitive to outliers and skewed distributions, and so would not
provide an accurate measure of central tendency. Instead, the median ($"p50"$)
and the Interquartile Range (IQR) were used. The $"p95"$, $"p99"$, $"p99.9"$,
$"p99.99"$, and maximum latency values were used to describe the worst-case
performance measurements.

The Kruskal-Wallis H test @kruskalWallis1952, a non-parametric method that is
robust to non-normal distributions and outliers, was used to compare the latency
and throughput distributions from the three runtime models. Dunn's test
@dunn1964 was used for post-hoc analysis to identify which implementations
differed significantly, with a Bonferroni correction @dunn1961 to control the
error rate and to prevent false positives.

Spearman's rank correlation coefficient ($rho$) @spearman1904 was used to
identify statistically significant correlations between the latency and
throughput with system events (e.g. backpressure, GC pauses, thermal
throttling). Unlike Pearson's correlation coefficient ($r$) @pearson1895,
Spearman's $rho$ considers the rank of the data rather than the raw values,
making it robust to non-normal distributions and extreme outliers. Furthermore,
Spearman's $rho$ can capture monotonic relationships that are not strictly
linear (i.e. relationships that consistently increase or decrease, but not
necessarily at a constant rate) @hauke2011, allowing correlations to be
identified even when exponential degradation occurs.
]

#wc[
=== Code Verbosity and Complexity

While this report's primary analysis is focused on comparing the performance of
the C++, Rust, and Python runtime models, language selection is often influenced
by development, maintenance, and testing overhead @ray2017. To evaluate the
trade-off between runtime efficiency and implementation verbosity, a
supplemental static code analysis was performed to compare the pipeline
implementations.

_Lizard_ @lizard is a code complexity analyser that supports C++, Rust, and
Python. It was utilised to determine: (1) the number of Lines of Code (LoC),
quantifying how verbose each implementation is, and (2) the Cyclomatic
Complexity (CC) @mccabe1976, quantifying the number of linearly independent
paths that exist in each implementation's source code. By measuring the LoC and
CC of identical backpressure and concurrency implementations in C++, Rust, and
Python, this analysis provides a partial insight into each runtime model's
development lifecycle overhead.
]

#wc[
=== Methodological Limitations

==== Memory Churn Asymmetry

An asymmetry exists in the measurement of memory churn across the three
implementations. When overriding `operator new` and `operator delete` in C++,
memory allocations made by third-party headers (e.g. #ct[TODO]) are captured,
but allocations made internally by pre-compiled shared libraries (e.g.
#ct[TODO]) are not. Similarly, in Rust, allocations made by idiomatic wrapper
crates (e.g. #ct[TODO]) are captured, but those in the underlying pre-compiled
libraries are not.

As both the C++ headers and the Rust wrapper crates use the same underlying C
API, they are symmetric in capturing the memory overhead required to serialise
data across the Foreign Function Interface (FFI). However, an asymmetry exists
in the capture of memory allocation within Python's third-party C-extension
bindings (e.g. #ct[TODO]), which do not use Python's memory manager and thus are
not visible to the telemetry thread when using `gc.get_stats()`. While this
asymmetry is a limitation when comparing memory churn across all three runtime
models, the methodology mitigates this by using the RSS as a baseline that
captures all memory demand regardless of its origin.

==== Temporal Alignment of Telemetry

Because `tegrastats` was executed as a separate process, it's sampling intervals
were not fully synchronised with the pipeline implementations. Therefore UNIX
timestamps (`CLOCK_REALTIME`) were recorded by both systems. Nearest-neighbour
interpolation was used during data aggregation to align the `tegrastats`
telemetry with the pipeline's latency and memory metrics, allowing for the
correlation of thermal events with performance degradation. This introduces a
maximum temporal misalignment of $plus.minus 500$ ms. Because thermal and
throttling state changes occur over seconds rather than milliseconds, this
sub-second uncertainty is accepted as a necessary limitation not expected to
significantly confound the results.

==== Static Complexity Analysis

Regarding the code verbosity and complexity analysis, metrics such as LoC and CC
only consider the static source code, and do not consider the learning curve or
cognitive complexity associated with each language (e.g. Rust's borrow checker
and ownership model, C++'s manual memory management, or Python's dynamic
typing). These can all significantly influence the development lifecycle
overhead, and therefore LoC and CC should be interpreted as partial measurements
of the engineering cost of language selection.

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
