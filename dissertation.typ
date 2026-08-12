#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import fletcher.shapes: cylinder, diamond, pill, rect
#import "@preview/wordometer:0.1.5": word-count, total-words

#show: word-count

#import "template.typ": template, ct, todo
#show: template.with(
  title: [AC52010 - MSc Project],
  assignment: [A Comparative Analysis of Memory Management, Concurrency, and
    Performance in Edge-AI],
  abstractTitle: [A Comparative Analysis of Memory Management, Concurrency, and
    Performance in Edge-AI],
)

#show "C++": box[C++]
#show "C++20": box[C++20]

#let red = rgb("F8D7DA")
#let dark_red = rgb("#E56C76")
#let light_red = rgb("#fce7f3")
#let blue = rgb("CCE5FF")
#let light_blue = rgb("#DBEDFF")
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
= Introduction

== Background and Context

In recent years, Edge-AI (Edge Artificial Intelligence) has begun to move the
deployment of AI models from centralised cloud-based servers to local devices,
such as sensors, mobile phones, and other embedded systems. This
decentralisation of AI processing offers several advantages over traditional
cloud computing: (1) it enables _real-time processing_ by removing network
latency, which is essential for time-sensitive applications such as autonomous
vehicles and industrial automation; (2) it drastically _reduces internet
bandwidth usage_, allowing systems to operate in environments where connectivity
is unreliable or unavailable, such as remote weather stations or satellite image
analysis; (3) it enhances _privacy and security_ by ensuring that sensitive
information, such as healthcare monitoring or smart home video feeds, is
processed locally and not transmitted across the internet; and (4) by removing
the need for continuous data transmission, Edge-AI can improve overall _energy
efficiency_ in battery-powered IoT deployments. These advantages are helping to
drive the expansion of large-scale Edge-AI projects, such as in smart city
infrastructure, where Edge-AI is increasingly deployed directly into municipal
infrastructure to improve efficiency and sustainability, such as in the control
of "smart" traffic lights or street lighting.

While recent advancements in heterogeneous System-on-Chips (SoCs) have made
Edge-AI deployments practical by integrating dedicated AI accelerators into
small form factors, these devices do bring challenges in terms of resource
constraints, such as limited memory, power consumption, and thermal limits.
Furthermore, remote software updates to maintain Edge-AI applications also come
at a cost, as they can be expensive and time-consuming, especially when dealing
with a large number of devices. The software must make maximum use of the
limited hardware resources, while also remaining stable over the long term,
making programming language selection an important design decision for Edge-AI
pipelines.

== Problem Statement <sec:problem-statement>

A language's runtime model dictates memory management, concurrency, and
scheduling behaviour under load, which directly impacts latency, throughput, and
resource usage. For example, manual memory management offers fine-grained
control and increased performance, but simultaneously increases the risk of
memory leaks and undefined behaviour. Conversely, memory management may be
automated through garbage collection (GC) at the cost of execution overhead and
unpredictable latency jitter.

This dissertation focuses on the performance metrics at the system level.
_Latency_ does not refer to network transmission time, but rather the processing
time from when the sensor data is created to when the final AI prediction is
completed. This includes queueing delays, inference time, and final fusion of
the prediction. A deadline of 100 ms is chosen for the tri-stream HAR pipeline,
based on what Xue et al. (2025) @xue2025 identified as the maximum allowable
latency for effective real-time coaching feedback. _Throughput_ measures how
many sensor events the pipeline can process per unit of time (e.g. per second)
when under sustained load.

Selecting a language for Edge-AI pipelines is often guided by familiarity or
generalised benchmarks, rather than the evaluation of runtime models under
stress with the constraints of embedded hardware. When deploying on Edge
hardware, the aforementioned challenges amplify the impact of programming
language choice. There is a lack of empirical evidence of how specific memory
management and concurrency models interact with backpressure policies under
heavy, fluctuating loads. Additionally, resource contention and thermal
throttling confounders can introduce noise that limits the validity of naive
comparisons.

This dissertation addresses the gap by providing empirical evidence and an
evaluation of pipelines deployed on resource-constrained hardware, with a focus
on the trade-offs among C++20 (with GCC \15.2.0), Rust (\1.97.1), and Python
(CPython \3.10.12) implementations of a tri-stream Human Activity Recognition
(HAR) pipeline on industry-standard Edge-AI hardware. It focuses on three
confounders: (\1) language runtime models, (\2) backpressure policies under
various loads, and (\3) thermal/power throttling.

== Research Questions and Objectives

The primary research questions are:

#text[
  #set enum(indent: 0em, numbering: n => [*RQ#n*])

  + *Runtime Performance:* How do the runtime models of C++, Rust, and Python
    influence latency, throughput, and memory consumption in a tri-stream HAR
    pipeline on Edge-AI hardware?

  + *Backpressure Interaction:* How do the runtime models interact with
    different backpressure policies under varying load, and what are the
    trade-offs in observed deadline adherence, system stability, and
    allocator/GC pressure and concurrency overhead?

  + *Dynamic Profiling vs. Runtime Behaviour:* To what extent do dynamic
    memory/concurrency profiling metrics explain the observed performance
    bottlenecks and trade-offs under load?
]

The primary research objectives are:

#text[
  #set enum(indent: 0em, numbering: n => [*RO#n*])

  + Implement a functionally identical tri-stream HAR pipeline in C++, Rust, and
    Python, ensuring optimised idiomatic implementations for each language.

  + Evaluate the performance of each implementation under controlled conditions,
    using a shared deterministic load generator, to quantify how backpressure
    policies and runtime models impact latency, throughput, memory consumption,
    and thermal/power dynamics under load.

  + Analyse runtime model overhead to explain performance differences, and
    derive empirically grounded guidance for language selection in constrained
    Edge-AI deployments.
]

== Research Contributions

This dissertation offers the following contributions to software engineering for
Edge-AI systems:

#text[
  #set enum(indent: 0em, numbering: n => [*C#n*])

  + *Cross-Language Runtime Evaluation:* Addressing RQ1, this work delivers an
    empirical comparison of how C++, Rust, and Python runtime models (memory
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

== Scope and Limitations

The focus of this dissertation is on the interaction of three language runtime
models (C++, Rust, and Python) with system latency and throughput, using
standardised, idiomatic implementations of a tri-stream HAR pipeline on
industry-standard Edge-AI hardware. The scope is limited to a standardised
implementation representative of real-world multi-modal processing, with
confounders limited to thermal/power throttling and backpressure policies.

The pipeline architecture, deterministic load generator, and backpressure
implementations are designed for portability across Linux environments. However,
AI acceleration, thermal behaviour, and power management are SoC-dependent.
Consequently, the profiling and acceleration tools used during evaluation (e.g.
NVIDIA tegrastats, TensorRT) are specific to the Jetson Orin Nano platform and
cannot be directly applied across other edge devices.

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


== Dissertation Outline

The remainder of this dissertation is structured as follows: #box[*Chapter 2*]
provides background on the evolution of Edge-AI and the heterogeneous devices
employed. It also introduces the programming languages evaluated in this
dissertation, and briefly explains the concepts of AI acceleration,
backpressure, and load shedding. #box[*Chapter 3*] reviews related literature
regarding language efficiency benchmarks, the trade-offs between memory safety
and cognitive load, backpressure policies, and measuring latency, concluding by
identifying the research gap. #box[*Chapter 4*] details the methodology,
including the hardware and software setup, backpressure interfaces, and
profiling toolchains used to collect metrics. #box[*Chapter 5*] describes the
implementation of the HAR pipeline in each language, highlighting
language-specific optimisations and challenges. #box[*Chapter 6*] presents the
results, including performance metrics, memory allocation and GC pressure, and
backpressure outcomes under varying loads. #box[*Chapter 7*] discusses the
findings and limitations of the study. Finally, #box[*Chapter 8*] concludes by
addressing the research questions, providing practical recommendations for
language selection in Edge-AI contexts, and suggesting directions for future
work.

= Background

== The Evolution of Edge Computing

The late 1990s saw a growth of online multimedia that demanded a solution to
tackle increased network congestion and latency. Karger et al. (1997)
@karger1997 proposed a concept of _distributed caching protocols_ that evolved
into modern-day _Content Delivery Networks_ (CDNs), ensuring that static content
could be cached on servers located closer to end-users, thus reducing latency
and bandwidth usage, especially during periods of high demand.

\2007 saw the release of the iPhone, followed by the Android operating system in
\2008, and the Windows Phone in \2010. These marked a rapid increase in the use
of mobile devices, and created user demand for computationally intensive
applications. However, as Satyanarayanan et al. (2009) @satyanarayanan2009
established, "considerations such as weight, size, battery life, ergonomics, and
heat dissipation exact a severe penalty in computational resources such as
processor speed, memory size, and disk capacity." To bypass these physical
limitations, they took the concept of CDNs further by proposing decentralised
and widely dispersed _cloudlets_ --- servers located on the network edge and
close to end-clients (e.g. in cafe premises) that run customised service
software using hardware VM technology, thus allowing mobile devices to act as
thin clients, overcoming hardware constraints without unacceptable latency and
bandwidth usage that would be introduced if remote cloud servers were used.

The next decade saw an explosive growth of the Internet of Things (IoT), fuelled
by the adoption in areas such as Fitness Wearables (the first Fitbit Tracker
launched in \2009), Smart Home devices (Google acquired Nest Labs in \2014, and
Amazon acquired Ring LLC in \2018), and "dockless" bicycle-sharing schemes (Lime
launched in \2017). Remote devices were no longer just data consumers, but had
also become data producers. Shi et al. (2016) @shi2016 defined "edge" not as a
specific device, but as any computing and networking resource along the path
between the data source and the data centre. They recognised that the data
bandwidth and centralised processing in traditional cloud computing were
bottlenecks, arguing that data should be processed at the proximity of the data
source.

At the same time, the integration of AI rapidly accelerated. While some
applications were designed to run on remote cloud servers (e.g. ChatGPT,
launched in late \2022), latency-critical applications depended on local-device
processing to ensure safety and reduce dependence on available network bandwidth
(e.g. Tesla Autopilot, launched in \2014, and the Waymo One in \2018).

This transition to _Edge-AI_ required overcoming the hardware obstacles
identified by Satyanarayanan et al. @satyanarayanan2009 and the network
bottlenecks identified by Shi et al. (2016) @shi2016 and Zhou et al. (2019)
@zhou2019 provided a comprehensive survey of recent research efforts in Edge
Intelligence, and identified that physical proximity to the data source is
critical to reducing monetary costs, latency, and the risk of privacy leakage.
For evaluating the quality of Edge-AI inference, they highlighted latency,
accuracy, energy consumption, privacy, and memory footprint. While communication
overhead is eliminated by offline edge processing, latency, energy consumption,
and memory overhead remain relevant to this dissertation. For example,
backpressure policies may intentionally drop data to ensure system stability,
sacrificing model accuracy to satisfy strict latency deadlines.

== Heterogeneous Devices and DVFS

Heterogeneous devices combine different types of processing units, such as a CPU
and a GPU, onto a single chip and are an increasingly common solution for
Edge-AI deployments. Modern heterogeneous SoCs, such as the NVIDIA Jetson Orin
Nano, integrate dedicated CUDA cores for general-purpose GPU computing, and
Tensor cores for AI acceleration. These allow optimised engines like TensorRT to
efficiently execute AI pipelines, such as HAR, locally without depending on
remote cloud servers. Furthermore, they support the enabling technologies
identified by Zhou et al. @zhou2019, such as model compression (e.g.
quantisation and pruning), to maximise inference speed.

However, embedded devices with a small form factor generate significant heat
when under sustained heavy load such as that generated by Edge-AI pipelines. To
prevent hardware failure, the Jetson Orin Nano relies on _Dynamic Voltage and
Frequency Scaling_ (DVFS) to reactively throttle the CPU and GPU speeds when
thermal limits are reached. Peluso et al. (2019) @peluso2019 demonstrated that
this introduces non-deterministic pipeline performance degradation. It can be
concluded that to minimise premature throttling, the software architecture and
language runtime model must be efficient by minimising unnecessary CPU and
memory overhead.

== AI Acceleration

To deploy AI models on resource-constrained edge devices, they must first be
compiled into a format that is optimised for the target AI acceleration
hardware. A software stack on the device is responsible for executing the model,
while the client, or _host_, manages the data transfer and inference
orchestration.

As visualised in @fig:cuda-arch, *CUDA* (Compute Unified Device Architecture)
@cuda provides a parallel execution environment and programming model for
heterogeneous computing systems with NVIDIA GPUs, using a Single Instruction
Multiple Threads (SIMT) architecture. In CUDA, the CPU is referred to as the
_host_, and the GPU is referred to as the _device_. CUDA clients are responsible
for managing the transfer of data between _host memory_ and _device memory_.

CUDA allows developers to write a _kernel_ function that is launched
asynchronously from the host code and executed in parallel across many threads
(using different data) on the device, enabling high-performance computing for AI
workloads. The kernel _threads_ are grouped into _thread blocks_, which in turn
are grouped into a _grid_. Each thread block is split into _warps_ of 32 threads
that are executed in lock step on a single device _Streaming Multiprocessor_.

#figure(
  pad(top: 1em, bottom: 0.5em)[
    #set text(size: 8pt)

    #let a(x, y, n) = node((x,y), stroke: none, name: n)
    #let c(x, y, n, t) = node((x,y), name: n, align(center)[#t],
      fill: pale_blue, shape: cylinder, inset: 5pt)
    #let r(x, y, n, t, f) = node((x,y), name: n, align(center)[#t],
      fill: f, shape: rect, corner-radius: 2pt)
    #let w(x, y, n, t) = r(x, y, n, t, pale_blue)
    #let e(p1, p2, t) = edge(p1, p2, "-|>", label: [#t],
      label-side: center, mark-scale: 150%, label-pos: 25pt)

    #diagram(
      node-stroke: 0.5pt + charcoal,
      spacing: (40pt, 20pt),

      a(0, 0, <host-anchor>),
      c(0, 0.5, <host-memory>, [Host Memory]),
      r(1, 0.5, <host-thread>, [Host Thread], rgb("#F1F5F9")),

      a(0, 3.0, <device-anchor>),
      a(1, 3.95, <sm-anchor>),
      a(1, 4.5, <warp-anchor>),
      w(1, 4.9, <warp-1>, [Warp (32 Threads)]),
      w(1, 5.5, <warp-2>, [Warp (32 Threads)]),
      c(0, 5.2, <device-memory>, [Device Memory]),

      node(
        enclose: (<host-anchor>, <host-memory>, <host-thread>),
        align(top + center, pad(top: -4pt, [*Host (CPU)*])),
        stroke: 1pt + charcoal,
        fill: pale_green,
        inset: 8pt,
        corner-radius: 4pt,
      ),

      node(
        enclose: (<device-anchor>, <device-memory>, <sm-enc>),
        align(top + center, pad(top: -3pt, [*Device (GPU)*])),
        stroke: 1pt + charcoal,
        fill: pale_green,
        inset: 8pt,
        corner-radius: 4pt,
      ),

      node(
        name: <sm-enc>,
        enclose: (<sm-anchor>, <warp-2>),
        stroke: 0.5pt + charcoal,
        fill: rgb("#FFFEF9"),
        align(top + center, pad(top: -13pt, [*Streaming\ Multiprocessor*])),
        inset: 16pt,
        corner-radius: 4pt
      ),

      node(
        enclose: (<warp-anchor>, <warp-1>, <warp-2>),
        stroke: (paint: rgb("#4A5568"), dash: "dashed", thickness: 0.5pt),
        fill: none,
        align(top + center, pad(top: -0.5em, [Thread Block])),
        inset: 10pt
      ),

      e(<host-memory>, <device-memory>, [Data Transfer]),
      e(<host-thread>, <sm-enc>, [Asynchronous\ Kernel Launch]),
    )
  ],

  caption: [CUDA Architecture Overview showing the host (CPU) and device (GPU)
    memory separation, and the asynchronous launch of kernel functions to the
    device.#v(1em)]
) <fig:cuda-arch>

*cuDNN* (CUDA Deep Neural Network) @cudnn is a GPU-accelerated library of
primitives for deep neural networks, that sits on top of CUDA and runs on the
device to provide higher-level abstractions and optimised implementations of
common deep learning operations (e.g. normalisation, matrix multiplication,
softmax, etc.).

*TensorRT* @tensorRT is responsible for compiling an *ONNX* (Open Neural Network
Exchange) @onnx model into a _.engine_ file, optimised to run on the Jetson GPU.

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
guarantee of memory correctness, but potentially increases cognitive load as the
OBRM is a novel concept that introduces a steep learning curve.

Python is a general-purpose language that is compiled to bytecode and
interpreted at runtime. It emphasises simplicity and ease of both writing and
reading. CPython (the reference implementation) has a Foreign Function Interface
(FFI) that allows it to interface with other languages, such as C/C++ libraries.
Python is often used to automate tasks and for data analysis and machine
learning. It utilises a Garbage Collector (GC), abstracting memory management to
reduce cognitive load and the risk of memory-safety bugs, but at the cost of
increased latency and unpredictable latency jitter due to "stop-the-world" GC
events which pause the executable's threads to safely clean up memory. Latency
is further impacted by CPython's Global Interpreter Lock (GIL), which prevents
true concurrency across multiple CPU cores by ensuring only one thread is
executed at any given time. However, C-extensions (such as ONNX) are able to
bypass the GIL, allowing them to run concurrently on multiple cores.

== Stream Processing & Backpressure

In stream processing systems, such as HAR pipelines, data is generated
continuously and must be processed in real-time. When the rate of generation
exceeds the system's processing capacity, backpressure builds up within the
pipeline as the number of unprocessed data items increases. This can lead to
memory exhaustion and system instability if not managed effectively.

However, because the pipeline cannot request the sensors to slow down their rate
of transmission, traditional backpressure mechanisms are impossible. Instead,
_load shedding_ policies are necessary. Policies such as dropping data (e.g.
dropping the oldest, newest, or every $n$-th frames) are commonly used to manage
backpressure, but introduce an accuracy trade-off as data is lost.

= Literature Review

== Benchmarking Language Efficiency

Empirical evaluations of programming languages highlight a trade-off between
execution speed, energy consumption, and memory footprint. In a comprehensive
study of \27 programming languages, Pereira et al. (2017) @pereira2017energy
showed that compiled languages typically  were the most performant, needed less
memory, and were more energy efficient. Conversely, interpreted languages
required the most memory, consumed the most energy, and were the slowest.

However, the reported results also indicated that execution speed and energy
efficiency do not perfectly correlate with memory efficiency. For example, in
the normalised results Rust performed second only to C in terms of energy
efficiency (1.03) and execution speed (1.04), but seventh (1.54) in terms of
memory usage.

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
the _concept_ of ownership, they struggled with the _semantics_ of references
and borrowing. This introduces a trade-off between memory safety and developer
cognitive load.

== Backpressure Policies

In Edge-AI pipelines, data generated by the sensors is often produced at a
faster rate than the hardware can process. Because real-time physical sensors
emit data continuously and cannot be paused, flow-control mechanisms are not
suitable. Therefore load shedding techniques are required to prevent memory
exhaustion otherwise caused by an explosive growth of unprocessed data. Recent
novel research has focused on techniques that dynamically drop frames based on
the load's content to maximise efficiency without degrading model accuracy. For
example, Li et al. @li2020 proposed filtering techniques that discard frames
based on video-frame deltas, shedding data when visual scene changes are
minimal. Similarly, Rivetti et al. @rivetti2016 explored load shedding based on
the estimated execution duration of the load using a cost model built and
maintained at run-time, intentionally bypassing processing that would cause the
latency threshold to be violated.

== Coordinated Omission <sec:coordinated-omission>

If a data-processing pipeline evaluation only starts to measure latency when
processing an event begins instead of when an event truly occurs, or when a
producer is stalled due to the lack of the consumer's readiness to process data,
it risks a phenomenon identified by Tene (2014) @tene2014 as _Coordinated
Omission_. This failure to record the true time that an event occurs means that
queue delays --- which may occur because of an OS context switch, a garbage
collection pause, thermal throttling, etc. --- are not recorded, consequently
reducing latency measurements. Furthermore, because fewer events are recorded
when the system is throttled or stalled, low-latency events form the majority of
the recorded dataset, making a system appear more performant than it actually
is.

Tene also warns against ignoring events beyond the 99th percentile, as doing so
fails to expose the frequency and impact of systematic delays. While Tene
advises that extreme percentiles (e.g. \99.9th and \99.99th) should be measured,
this dissertation captures only to the \99.9th percentile due to the limited
number of events ($< \10,000$) that are generated during a one-second epoch.

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

Studies that have proposed novel load-shedding techniques @li2020 @rivetti2016
have not evaluated the impact of the runtime model on the performance of the
backpressure policies, instead treating the programming language as zero-cost.
For example, there is no evaluation of how the memory model of the language
impacts the performance of policies when data is dropped, such as whether
Python's GC introduces jitter when reclaiming memory.

Therefore, there is a research gap in empirically evaluating how the C++, Rust,
and Python runtime models interact with backpressure policies under the thermal
constraints of Edge-AI devices with continuous streams of sensor data.
Consequently, capturing true latency measurements at high percentiles under
heavy load is necessary to determine their suitability for Edge-AI pipelines.

= Methodology

== Hardware Stack

The NVIDIA Jetson Orin Nano (8GB Edition) was utilised as the target Edge-AI
platform. It is a high-performance heterogeneous computing platform designed for
Edge-AI development in embedded systems, allowing complex AI workloads and
multi-stream pipelines to be run efficiently.

The developer kit includes a carrier board with I/O interfaces (e.g. USB,
Ethernet, DisplayPort), a MicroSD card slot for initial booting without an NVMe
SSD, and the Jetson Orin Nano module itself. This provides the following
specifications @jetson-orin-nano @a78RefManual:
- 6-core Arm Cortex-A78AE 64-bit CPU (clocked to 1.7 GHz) for general-purpose
  concurrent processing
- up to 67 TOPS (Tera Operations Per Second) of AI performance
- 8 GB of 128-bit LPDDR5 memory with a bandwidth of 102 GB/s
- 1024 CUDA cores for general-purpose GPU computing
- 32 Tensor cores for AI acceleration
- L1 and L2 caches with 64-byte cache lines

The Jetson came pre-flashed with NVIDIA’s JetPack 6.2 SDK @jetpack-6-2 which
provides _Super Mode_ and uncapped _SUPER MAXN_ power mode that enables the
highest number of cores and clock frequency across the SoC.

A Waveshare IMX219-160 Camera Module @imx219-160 was used to deliver the RGB
video stream, configured to capture at 1920×1080 RGB frames at \30 FPS, and
connected via MIPI CSI-2 (Mobile Industry Processor Interface Camera Serial
Interface \2). The camera captures images with a field of view (FOV) of
160#sym.degree, making it suitable for capturing a wide area for human activity
recognition after undistortion.

A Bosch Sensortec BMI088 IMU Shuttle Board 3.0 @bmi088 was used to provide
inertial measurement data, configured to capture 6-axis data, and connected via
SPI for maximum throughput. The BMI088 combines a 3-axis accelerometer and a
3-axis gyroscope, providing two complementary data streams at up to 1.6 kHz
(accelerometer) and 2.0 kHz (gyroscope).

To ensure that disk I/O did not cause bottlenecks or confound performance
comparisons, all implementations were executed from a 1TB Samsung \990 PRO PCIe
\4.0 NVMe M.2 SSD @samsung-990-pro. A SanDisk "High-Endurance" microSD Card
(64GB, Class 10/U3) @sandisk-micro-sd was only used for initial device
installation, and was physically removed after the NVMe SSD was installed.

== Software Stack

The Jetson was already flashed with NVIDIA's JetPack \6.2 SDK @jetpack-6-2,
which includes Jetson Linux 36.4.3 (featuring the Linux Kernel 5.15 and an
Ubuntu \22.04-based root file system), and CUDA \12.6.10, cuDNN \9.3.0, and
TensorRT \10.3.0 for AI inference and acceleration. The software stack versions
were selected as the most recent stable releases at the time of development, and
were used for all implementations to ensure a consistent baseline for
comparison. The Jetson Linux operating system utilises the GNU C Library (glibc)
memory allocator, which in turn is used by the installed C++ and Rust toolchains
as they rely on the system allocator. This enables use of glibc-specific tools
for analysis of memory fragmentation.

All implementations interact with the ONNX Runtime 1.24.0 to load and execute
the AI model, which is responsible for the data transfer and inference
orchestration on the host, and hands off responsibility to TensorRT for
inference execution on the device. To ensure a consistent baseline, functionally
identical TensorRT context files (`_epctx.onnx`) were used across all three
implementations. C++ and Python both use the same cached files, but because
Rust's Ort crate uses a newer version of the ONNX Runtime API, it was required
to generate separate cached files. However, as these were generated from the
same `.onnx` files, all three implementations used the same model weights and
functionality.

Performance and overhead of the language runtime models was measured at the
boundary of the host/device memory separation, where the CPU manages the runtime
model, and the SIMT architecture runs the AI workloads on the GPU. This prevents
confounding the results with hardware latency, and provides a clearer comparison
of how each language's runtime model performs under load and backpressure.

A Docker container, based on NVIDIA's official _l4t-jetpack_ image (36.4.0
@l4t-jetpack-36-4-0), was used to prevent host updates to ensure that the
software toolchains and environment variables remained consistent for all
implementations. While Docker introduces some performance overhead, it was
considered acceptable to ensure a consistent and reproducible environment for
all implementations. Five Docker arguments were used for every container:
`--ipc=host` to allow access to the host's shared memory, `--privileged` and
`--runtime=nvidia` to allow access to the GPU and Jetson device nodes,
`--cap-add=SYS_NICE` to allow real-time scheduling, and
`--volume=$(pwd)/results:/results` to allow the container to write results to
the host file-system. The generator was detached, using the Docker argument
`--detach`, so that it would execute in the background, and pinned to core \5
using the generator's own `--core` argument to prevent context switching
overhead. The pipelines were restricted to cores \1-\4 using Docker's
`--cpuset-cpus` argument to prevent them running on the same core as either the
Linux kernel (core \0) or the generator.

The latest stable releases of the language toolchains, which were compatible
with the Ubuntu \22.04-based root file system, were used for all
implementations: C++20 with GCC \15.2.0, Rust \1.97.1 and CPython 3.10.12.
CPython is the default Python interpreter for many Linux distributions, and
implements the runtime model, including the GIL and GC, that is evaluated in
this report.

== Deterministic Load Generator

To reliably compare the performance of the three implementations, a separate
synthetic load generator, shown in @fig:architecture, was developed to create
reproducible and deterministic simulated sensor data. This ensures that the
behaviour of each implementation can be compared using the same baseline data,
and that differences in performance can be attributed to the runtime models and
backpressure policies, and not input variability.

The load generator produces three streams of data to shared memory buffers for
consumption by the HAR pipelines: (1) an RGB video stream to simulate the
camera, (2) a 3-axis inertial measurement stream to simulate the accelerometer,
and (3) a 3-axis inertial measurement stream to simulate the gyroscope. Using
shared memory allowed for low-latency communication, and for the generator to
write data at a consistent rate. The shared memory buffers were implemented as
fixed capacity ring buffers, allowing the generator to write data without being
blocked by the pipeline.

The generated image data was random noise. Each image was created as an array of
RGB pixel values with dimensions of 1920x1080 to match the sensor data, and each
pixel's red, green, and blue values were assigned random whole numbers in the
range $[0,255]$. Similarly, the generated IMU data was random floating-point
numbers within the maximum hardware ranges of the BMI088 sensor
(#sym.plus.minus\24g for acceleration and #sym.plus.minus\2000#sym.degree/s for
angular rate).

A hard-coded seed for each sensor ($"rgb" = 42, "accel" = 43, "gyro" = 44$) was
used to create the three deterministic data-streams to ensure the same generated
data was fed into each implementation. To improve efficiency of the runtime
behaviour and allow faster generation, the random synthetic data for each stream
was pre-generated during program initialisation to avoid the overhead of
continuous pseudo-random number generation. Each synthetic data pool was large
enough for a continuously cycled temporal window of one second to allow
variation in the data streams without exhausting the device's available memory.
Because the AI inference is only a repeatable workload to determine the
performance of the runtime models, and prediction accuracy does not impact the
evaluation, the generated data was not designed to be realistic. This kept the
load generator implementation simple, does not introduce disk I/O bottlenecks,
and reduced latency and overhead that could confound the results by stealing CPU
cycles or memory bandwidth from the pipelines.

To allow backpressure policies to be evaluated under varying load, the generator
accepts a _load_ parameter that dictates the speed at which data is produced by
acting as a multiplier of the baseline sensor intervals. This multiplier is
applied equally to all three data streams to ensure the ratio between the camera
and the IMU data remains consistent. For example, a value of \1.0 produces data
at the same rate as the sensors: \30 FPS for the camera (\1 frame every \33.3
ms), and \1.6 kHz and \2.0 kHz for the accelerometer and gyroscope respectively
(\0.625 ms and \0.5 ms intervals respectively). A value of \2.0 produces data
twice as fast, \0.5 produces data at half the speed, and so on. 100% saturation
of the pipelines was determined by adjusting the load argument until one or more
of the pipelines were consistently backpressured (see @sec-backpressure).

The load generator was written in Rust to take advantage of its performance and
memory safety guarantees. For maximum timing accuracy,
`nix::time::clock_nanosleep` was used to implement the timing of the data
generation. `CLOCK_MONOTONIC` was used for high resolution timing, and Network
Time Protocol (NTP) synchronisation was disabled using
`timedatectl set-ntp false` to prevent the system clock from being adjusted
during the experiments. The generator was pinned to one CPU core to prevent
jitter caused by the overhead of saving and restoring the generator thread
state, and the process was given a real-time scheduling policy. The generator
and pipelines were prevented from running on core \0 to avoid contention with
the Linux kernel and background processes.

The deterministic load generator and HAR pipelines were designed to allow
seamless substitution of the generator with a physical hardware harness, using
shared memory (`/dev/shm`) ring buffers as the communication boundary. A
physical hardware test was initially planned. However, damage to the Jetson Orin
Nano Developer Kit's MIPI CSI-2 ZIF connector during assembly prevented the
connection of the Waveshare IMX219-160 Camera Module. Investigation revealed
that these ZIF connectors are notoriously fragile, further validating the need
for a deterministic generator to execute the high-stress evaluations required
for this dissertation's research.

#figure(
  scope: "parent",
  placement: top,

  [
    #set text(size: 8pt)

    #let n(x, name, t, f, s) = node((x,1), name: name, align(center)[#t],
      fill: f, shape: s)
    #let r(x, name, t) = n(x, name, t, pale_green, rect)
    #let c(x, name, t) = n(x, name, t, pale_blue, cylinder)
    #let e(p1, p2, t, p) = edge(p1, p2, "-|>", mark-scale: 175%,
      label: align(center)[#t], label-side: left, label-pos: p)

    #diagram(
      node-stroke: 0.5pt + charcoal,
      node-corner-radius: 2pt,
      node-inset: 6pt,
      spacing: (40pt, 12pt),

      node((3,0), align(center)[*HAR Pipeline*], stroke: none),
      node(
        enclose: ((2,1), (4,1)),
        stroke: (paint: charcoal, dash: "dashed", thickness: 1pt),
        inset: 12pt
      ),

      r(0, <generator>, [Load Generator\ (Rust)]),
      c(1, <unbounded>, [Unbounded Ring Buffer\ (Shared Memory)]),
      r(2, <bridge>, [Language Bridge\ (C++/Rust/Py)]),
      c(3, <bounded>, [Bounded Buffer\ (Idiomatic)]),
      r(4, <inference>, [AI Inference\ (TensorRT)]),

      e(<generator>, <unbounded>, [Push], 0.5),
      e(<unbounded>, <bridge>, [Poll], 0.35),
      e(<bridge>, <bounded>, [Push/Drop], 0.5),
      e(<bounded>, <inference>, [Dequeue], 0.5),
    )
  ],

  caption: [System architecture demonstrating communication between the separate
    Load Generator and the HAR Pipeline implementations.#v(1em)],
) <fig:architecture>

== Backpressure Policies <sec-backpressure>

Bounded backpressure policies are implemented in each language-specific runtime
model. In a typical backpressure implementation, when a _consumer_ is saturated
(i.e. the buffer is full), the active backpressure policy is triggered to slow
the flow of data from the _producer_ to prevent unbounded memory demand and
system instability.

The backpressure policies were implemented in the pipelines using two buffers
per data stream: (1) an unbounded _producer buffer_ in shared memory for the
load generator to write data into, allowing it to produce data at a consistent
rate, and (2) a _consumer buffer_ for the pipelines to read data from for
processing, with a fixed capacity to trigger the backpressure policy when full.

Using Little's Law ($L = lambda W$) @little1961, the capacity of each consumer
buffer was determined by multiplying the _target_ baseline throughput ($lambda$)
by the maximum deadline ($W$) for processing an event. The target throughput is
based on the _native_ generation rate of the physical sensors (i.e. a load
multiplier of \1.0), allowing the pipelines to be tested under simulated system
stress relative to the baseline speed of the physical sensors. As stated in
@sec:problem-statement, a maximum deadline of \100 ms was selected based on Xue
et al. (\2025) @xue2025, resulting in a capacity of \3 for the RGB stream (\30
FPS), \160 for the accelerometer stream (\1.6 kHz), and \200 for the gyroscope
stream (\2.0 kHz).

#figure(
  pad(top: 1.5em)[
    #set text(size: 8pt)

    #let n(x, y, t, w) = node((x,y), align(center)[#t], shape: rect,
      width: w, height: 3em)
    #let s(x, y, name, speed) = n(x, y, [*#name*\ $lambda = #speed$], 8.18em)
    #let c(x, y, num) = n(x, y, [Capacity: *#num*], 7.06em)
    #let e(p1, p2) = edge(p1, p2, "-|>")

    #diagram(
      node-stroke: 0.5pt,
      node-corner-radius: 2pt,
      spacing: (4em, 1.5em),

      node((0, 0), shape: rect, fill: luma(240), width: 7.38em, height: 4.5em,
        align(top + center)[*Data Streams* \ ($lambda$ Hz)]),
      node((1, 0), shape: rect, fill: luma(240), width: 7.06em, height: 4.5em,
        align(top + center)[*Little's Law* \ ($L = lambda W$) \ $W = 0.1$s]),

      s(0, 1, [RGB], 30),
      c(1, 1, 3),
      e((0, 1), (1, 1)),

      s(0, 2, [Accelerometer], 1600),
      c(1, 2, 160),
      e((0, 2), (1, 2)),

      s(0, 3, [Gyroscope], 2000),
      c(1, 3, 200),
      e((0, 3), (1, 3)),

      edge((0, 0), (0, 1), "-|>", stroke: (dash: "dashed")),
    )
  ],
  caption: [Application of Little's Law to derive the bounded queue capacities
    from the data stream rates and the maximum latency deadline of \100 ms.
    #v(1em)],
) <fig:little-law>

The bounded buffers were implemented as fixed-capacity circular queues using
contiguous arrays in each language (`std::vector` in C++, `Vec` in Rust, and a
`list` in Python). Standard mutexes were employed to guarantee multi-threading
safety during enqueue and dequeue operations.

Backpressure is implemented only in the pipeline on the consumer buffer, forcing
each language runtime model to handle concurrency, memory allocation, and
scheduling within realistic constraints and allowing us to evaluate RQ2. A
_bridge_ in the pipeline is responsible for copying data from the producer
buffer to the consumer buffer, and for triggering the backpressure policy when
the consumer buffer is full.

Five backpressure and load shedding policies were implemented to manage queue
saturation when the consumer buffer is full:

*Policies that attempt to preserve all data (Flow Control):*
  - *Bounded queue:* Blocks the producer until space is available in the
    consumer buffer.
  - *Exponential-backoff:* Waits a short time before retrying to insert the
    data, with the wait time increasing each time by a configurable factor until
    a maximum wait time is reached (after which the data is dropped).

*Policies that intentionally drop data (Load Shedding):*
  - *Drop-oldest:* Drops the oldest data in the consumer buffer to make room for
    new data.
  - *Drop-newest:* Drops incoming data when the buffer is full.

*Policies that drop data while preserving temporal continuity:*
  - *Adaptive decimation:* Dynamically downsamples the data stream (i.e.
    queueing only every _nth_ frame) to reduce pressure on the consumer buffer
    while preserving the temporal continuity of the data. As the consumer buffer
    fills, the decimation factor is increased to reduce the number of frames
    being queued. Similarly, as the consumer buffer empties, the decimation
    factor is decreased. If the queue reaches full saturation, the oldest frame
    is dropped to make room for the newest frame.

Bounded queue and exponential backoff are both flow control policies, and
instead of dropping data they stall the data producer when the consumer buffer
is full. However, this can lead to unbounded memory growth of the producer
buffer, causing system instability. Conversely, drop-oldest, drop-newest, and
adaptive decimation are all load shedding policies that discard data, as
visualised in @fig:load_shedding, though this does lead to a loss of temporal
continuity and may impact prediction accuracy.

#figure(
  [
    #let n(n) = box(width: 1.2em, height: 1.2em,
      text(fill: luma(80), size: 0.9em)[#align(center+bottom)[#n]])
    #let p(c, t) = box(width: 1.2em, height: 1.2em, stroke: 0.5pt + grey,
      fill: c, radius: 2pt, align(center+horizon)[#t])
    #let k() = p(green, sym.checkmark)
    #let d() = p(red, sym.crossmark)

    #pad(bottom: 0.75em)[
      #grid(
        columns: (100pt, auto),
        align: (right + horizon, left + horizon),
        row-gutter: (0.3em, 1.5em, 1.5em, 1.5em),
        column-gutter: 1.5em,

        [],
        stack(dir: ltr, spacing: 6pt, n(1), n(2), n(3), n(4), n(5), n(6)),

        [*Incoming Stream:* \ _(Frames 1 to 6)_],
        stack(dir: ltr, spacing: 6pt, k(), k(), k(), k(), k(), k()),

        [*Drop-Newest:* \ _(Queue full at 4 frames)_],
        stack(dir: ltr, spacing: 6pt, k(), k(), k(), k(), d(), d()),

        [*Drop-Oldest:* \ _(Queue full at 4 frames)_],
        stack(dir: ltr, spacing: 6pt, d(), d(), k(), k(), k(), k()),

        [*Adaptive Decimation:* \ _(Queueing every 2nd frame)_],
        stack(dir: ltr, spacing: 6pt, k(), d(), k(), d(), k(), d()),
      )
    ]
  ],

  caption: [Load shedding policies on a stream of frames. Green check-marked
    (#sym.checkmark) blocks represent preserved data, red cross-marked
    (#sym.crossmark) blocks represent dropped data. #v(1em)],
) <fig:load_shedding>

The exponential backoff policy was configured with an initial wait time of \1 ms
--- sufficient time to allow the scheduler to yield to the inference thread,
providing an opportunity for space to become available in the consumer buffer.
The wait time is doubled upon each retry, up to an accumulated maximum of \33.3
ms before the frame is dropped. This maximum wait time was derived from the
generation interval of the \30 Hz RGB anchor stream. If exponential backoff were
to wait longer then it would cascade delays to the next late-fusion window.
Therefore, dropping the stalled frame effectively resets the pipeline, providing
an opportunity to recover and the next frame to be ingested in time to meet the
\100 ms latency deadline.

The adaptive decimation policy was configured to activate at 80% of each
stream's consumer buffer capacity (i.e. 2 frames for RGB, 128 for accelerometer,
and 160 for gyroscope). This provides 20% of queue capacity for the algorithm to
dynamically scale how much load is shed before the queue is saturated. At 80%
capacity, the pipeline is struggling to keep up with the rate of generation, and
so 50% of the frames are dropped (i.e. every second frame is queued) to allow
the pipeline to recover. If the consumer buffer continues to fill, the
decimation factor is linearly scaled until it reaches a maximum of 90% drop-rate
(i.e. only every 10th frame is queued by overwriting the oldest frame) at full
saturation. Should the consumer buffer remain at full saturation, the oldest
frame is dropped to make room for the newest frame, ensuring that the most
recent data is retained for inference.

To ensure the runtime models were evaluated under sustained stress, the
saturation threshold was determined by increasing the _load_ multiplier until at
least one consumer buffer reached capacity, ensuring the backpressure mechanism
was continuously engaged across all policies. Because the languages differ in
performance, a separate, fixed load multiplier was determined for each language.
This isolated the memory and scheduling behaviours of the runtime models,
removing execution speed as a confounding variable, and ensured that all five
backpressure policies within a given language were evaluated under an identical
ingestion rate.

== False Sharing

Modern CPU architectures contain multiple caches for each core to significantly
reduce memory access latency. These are designated a level (e.g. L1, L2) to
indicate how far away they are physically from the CPU core, and typically
increase in size and latency as their level increases. Each cache is split into
multiple _cache lines_, where the data is stored and can be written or read
significantly faster than from main memory. However, because the low-level cache
lines are not shared between cores, if a process on one core updates data in a
cache line, then processes on other cores that need to read that data must
update their own cache lines by fetching the refreshed data from higher-level
shared caches or main memory.

_False sharing_ occurs when an update to data held in a cache line causes other
cores to invalidate their own cache lines, even if the data being read is
otherwise unrelated to the data being written. For example, if a 32-byte
structure is stored in RAM at address range 0x1000--0x1020, a CPU with 64-byte
cache lines will store 64 bytes of data in its cache line covering the address
range 0xA000--0xA040, even though the last 32 bytes are unrelated to the
original structure. If those adjacent 32 bytes are updated, it will trigger a
refresh of the entire 64-byte cache line, invalidating the first 32 bytes and
forcing a read penalty.

Because the shared memory buffers are held in contiguous memory, false sharing
needed to be mitigated to prevent cache line invalidation of the header when
adjacent data frames were updated. This was achieved by using language-specific
techniques to pad the header to exactly 64 bytes in size and align its starting
address to a 64-byte boundary, ensuring it would be cached in isolation.

While the shared memory buffers are bound to one-second cycles, and consequently
false sharing would occur only twice per second if 64-byte alignment were not
enforced (once for the timestamp and once for the payload), ensuring cache
isolation of the header reflects best engineering practice and prevents
potential system degradation caused by future modifications to the
implementation.

== Memory Ordering

Traditional mutexes force a thread to yield to the system kernel. This
introduces latency and context-switching jitter, which may cause the generator
and pipelines to violate their timing constraints at the Inter-Process
Communication (IPC) boundary. To avoid this, wait-free spin-loops were used,
which required the use of atomic _memory ordering_.

The load generator updates the unbounded ring buffer's `seq_num` to inform the
pipeline that a new data frame has been written, and the pipeline spin-loops and
reads the new data as soon as it sees the `seq_num` updated. Without memory
ordering, the CPU may choose to update these apparently unrelated variables
"_out of order_" from what the code specifies. This would be catastrophic, as
the pipeline may read the stale data before the new data is committed. To
prevent this, the `seq_num` was declared as an atomic variable, and release
memory ordering was used when the generator updated it, informing the CPU that
all previous writes to any variable must be committed before the `seq_num` is
updated. Conversely, when the pipeline reads the `seq_num`, it uses acquire
memory ordering to inform the CPU that it must not speculatively read any other
variables before the `seq_num` is read. This simple "fence" guarantees that the
memory ordering is correct, and that the apparently unrelated `seq_num` and data
frame are read in the correct order.

== Zero-Allocation

To reduce memory churn and the latency jitter that may be introduced by
high-frequency dynamic memory allocation --- as well as GC pauses in Python ---
a zero-allocation approach was used. This was achieved by ensuring all necessary
memory (e.g. the bounded queue) was pre-allocated during initialisation, and
lightweight data structures (e.g. the telemetry `Epoch`) were continuously
reused rather than reallocated.

A buffer was pre-allocated in each inference thread to copy the payload from
every frame in the temporal window, providing a contiguous data source for the
TensorRT engine without utilising dynamic memory allocation. This was necessary
because the shared memory buffer operates as a ring, and so a temporal window
may wrap around the physical memory, causing later frames to precede earlier
frames. Furthermore, each frame contains a timestamp before the payload, causing
the data to be strided. The contiguous buffer was bound to the inference
execution context (using `Ort::IoBinding` for C++, `ort::value::TensorRef` for
Rust, and `onnxruntime.IOBinding` for Python) to prevent the TensorRT engine
from dynamically allocating memory or internally copying data during inference.

== AI Model Generation

Hardware-agnostic `.onnx` AI model files were generated offline using PyTorch
\2.13.0. Dynamic axes (i.e. allowing the inference data to be of variable sizes)
were forbidden to ensure that the TensorRT engine would not dynamically allocate
memory during inference, instead allocating memory once upon startup thus
improving performance and preserving the zero-allocation approach. These models
were then transferred to the Jetson Orin Nano and saved to hardware-specific
`_epctx.onnx` (Execution Provider Context) files using ONNX Runtime \1.24.0
before pipeline evaluation commences. These files ensure that the models do not
need to be re-optimised at startup for each evaluation. While C++ and Python
were able to share the same context files, Rust uses a newer C-API and thus was
required to cache its own versions to disk. However, due to the shared `.onnx`
model files, both sets used identical parameters and optimisations, ensuring
functional equivalence across all three implementations.

== Profiling and Metrics

=== Latency

To measure latency of the pipelines, the `CLOCK_MONOTONIC` clock was used to
capture high-resolution timestamps at key points as the frames flowed through
the pipeline. NTP synchronisation was disabled to prevent the system clock from
being adjusted. The following six timestamps, as visualised in
@fig:latency_timeline, were captured for each event:

+ `generated_ts` when the generator pushes to the unbounded ring buffer
+ `bridged_ts` when the bridge pushes to the bounded buffer
+ `pipeline_in_ts` when the pipeline pulls the frame from the idiomatic buffer
+ `pipeline_out_ts` when the pipeline pushes data to the ONNX Runtime for
  inference
+ `fusion_in_ts` when inference completes and the pipeline begins late fusion
+ `fusion_out_ts` when late fusion completes and the pipeline produces the final
  output

#figure(
  placement: top,
  scope: "parent",

  // pad(top: 1em, bottom: 0.5em)[
  pad(bottom: 0.5em)[
    #let n(x, name, t) = node((x,0), name: name, t)
    #let e(p1, p2, t, s, ls) = edge(p1, p2, "|-|", align(center)[#t],
      shift: s, label-sep: 0.25em, label-side: ls)
    #let te(x, y, t) = e(x, y, t, 25pt, left)
    #let be(x, y, t) = e(x, y, t, -25pt, right)

    #diagram(
      node-stroke: 0.5pt + charcoal,
      node-fill: pale_cream,
      node-corner-radius: 1.5pt,
      node-inset: 5pt,
      spacing: 25pt,

      edge((0,0), (5,0), "-", stroke: 1pt + charcoal),

      n(0, <generated>, [`generated_ts`]),
      n(1, <bridged>, [`bridged_ts`]),
      n(2, <pipeline-in>, [`pipeline_in_ts`]),
      n(3, <pipeline-out>, [`pipeline_out_ts`]),
      n(4, <fusion-in>, [`fusion_in_ts`]),
      n(5, <fusion-out>, [`fusion_out_ts`]),

      be(<generated>, <bridged>, [Unbounded\ Queue Wait]),
      te(<bridged>, <pipeline-in>, [Bounded\ Queue Wait]),
      be(<pipeline-in>, <pipeline-out>, [Inference\ Execution]),
      te(<pipeline-out>, <fusion-in>, [MPSC Wait]),
      be(<fusion-in>, <fusion-out>, [Fusion\ Execution]),

      e(<generated>, <fusion-out>, [Total Latency], -65pt, right),
    )
  ],

  caption: [Timeline of the six timestamps captured for each event as the frame
    flows through the pipeline. #v(1em)]
) <fig:latency_timeline>

To prevent Coordinated Omission as identified in @sec:coordinated-omission, the
load generator is decoupled from the pipelines. By ensuring that it pushes to an
unbounded ring buffer, it is never blocked when the System Under Test (SUT) is
stalled, thus guaranteeing that `generated_ts` allows queueing delays and
tail-latency to be accurately captured.

These timestamps provide five key latency measurements: _Unbounded Queue Wait_
($"bridged_ts" - "generated_ts"$), _Bounded Queue Wait_ ($"pipeline_in_ts" -
"bridged_ts"$), _Inference Execution_ ($"pipeline_out_ts" - "pipeline_in_ts"$),
_MPSC Wait_ ($"fusion_in_ts" - "pipeline_out_ts"$), and _Fusion Execution_
($"fusion_out_ts" - "fusion_in_ts"$). Additionally, _Total Latency_
($"fusion_out_ts" - "generated_ts"$) was calculated to capture the end-to-end
processing time.

These measurements provide the necessary granularity to measure each runtime
model's latency, and to identify bottlenecks and trade-offs under load and
backpressure.

To retain temporal information about how latency changes over time and
correlates with runtime model behaviour and backpressure events, a
triple-buffering approach was used (see @fig:triple-buffering). The pipeline
thread (the _writer_) populated an active `Epoch` object containing the latency
histograms, memory counters, and dropped frames counter. At one-second
intervals, a clean `Epoch` was pulled from a channel using wait-free message
passing, and the populated `Epoch` was pushed to another channel. Concurrently,
a lightweight background telemetry thread (the _reader_) pulled the populated
`Epoch` messages from the second channel and saved the counters and the $"p50"$,
$"p95"$, $"p99"$, $"p99.9"$, $"p99.99"$, and maximum latency values into a CSV
file, then reset the `Epoch` and pushed it back to the first channel for reuse.
A third `Epoch` was kept idle in the first channel ready to be swapped in as the
new active buffer, preventing any blocking of the pipeline thread if the
telemetry thread is delayed (e.g. by I/O stalls).

High Dynamic Range (HDR) Histograms @hdrhistogram were used to aggregate the
latency distributions, preventing memory allocation from polluting the latency
measurements that would occur if the measurements were stored in standard data
structures (e.g. vectors or lists).

#figure(
  pad(top: 1.5em)[
    #set text(size: 8pt)

    #let n(x, y, name, t, f, s) = node((x,y), name: name,
      align(center)[#t], fill: f, shape: s)
    #let r(x, y, name, t) = n(x, y, name, t, pale_green, rect)
    #let c(x, y, name, t) = n(x, y, name, t, pale_blue, rect)
    #let e(p1, p2, t, ls) = edge(p1, p2, "-|>", mark-scale: 175%,
      label: align(center)[#t], label-side: ls)

    #diagram(
      node-stroke: 0.5pt + charcoal,
      node-corner-radius: 2pt,
      node-inset: 8pt,
      spacing: (70pt, 60pt),

      r(0, 0, <writer>, [Pipeline Thread\ (Writer)]),
      r(1, 0, <reader>, [Telemetry Thread\ (Reader)]),

      c(0, 1, <active>, [Active\ Epoch Buffer]),
      c(1.05, 1.05, <idle>, [Idle & Idle\ Epoch Buffers]),
      c(1, 1, <inactive>, [Idle & Inactive\ Epoch Buffers]),

      e(<writer>, <active>, [Record Metrics\ (Wait-Free)], center),
      e(<reader>, <inactive>, [Extract Telemetry\ (CSV I/O)], center),

      edge(<active>, <inactive>, "<|--|>", mark-scale: 175%,
        label: align(center)[Channel Swap\ (1 Hz Interval)], label-side: right)
    )
  ],

  caption: [Triple-buffering approach to cleanly capture the telemetry epochs \
    without blocking the pipeline thread during I/O stalls.]
) <fig:triple-buffering>

=== Memory Churn (C++ and Rust)

To measure the rate of memory churn in C++ and Rust (RQ3), the global memory
allocation and deallocation functions were overridden to capture memory
allocation metrics, without relying on third-party profiling tools that may
introduce additional overhead and confound the results. In C++, the
`operator new` and `operator delete` functions were overridden, and in Rust a
custom memory allocator was implemented as the standard library's default by
using the `#[global_allocator]` attribute.

The telemetry thread concurrently captured the memory allocation metrics during
the same intervals as the latency measurements, allowing for correlation between
memory churn under load and backpressure events. Three atomic operations
(`std::atomic<size_t>` in C++, and `AtomicUsize` in Rust) were used to capture
the total number of allocations, total bytes allocated, and total bytes freed.
Relaxed memory ordering was used to prevent the "observer effect" from
confounding the results by introducing additional latency. Though this may
introduce nanosecond-level "read skew" when the telemetry thread reads the
counters (i.e. the independent metrics are read slightly out of sync with each
other), the telemetry thread only reads these metrics once a second, which
renders this comparatively insignificant temporal drift statistically
irrelevant.

=== GC Pressure (Python)

Python uses a Garbage Collector (GC) to manage memory, which can introduce
non-deterministic tail-latency GC pauses (also known as "stop-the-world" events)
when run. Using `tracemalloc` from the standard library would introduce
additional overhead and confound the results, as it introduces tracing for every
memory allocation event. Instead, the GC's built-in `callbacks` hook was
utilised to capture the start and end time of each GC event (using
`CLOCK_MONOTONIC`) to calculate the duration of each pause.

To prevent memory allocation within the callback function, a triple-buffering
approach was used, similar to the latency measurements, where the callback
function writes the GC pause durations to an active `Epoch` without blocking.
The background telemetry thread then extracts the GC pause percentiles and
maximums at the same time as the latency measurements, allowing correlation
between GC pause durations and runtime model events.

The telemetry thread also employs `gc.get_stats()` to capture the cumulative
number of objects collected since the Python interpreter was started, from which
the rate of object collection across Generations 0, 1, and 2 can be calculated
using a delta between intervals. This function does not include objects that are
deallocated immediately using Python's main reference counting mechanism, but it
does provide the data to correlate deep Generation 2 collection events with
tail-latency pauses.

=== Memory Fragmentation

Repeated allocation and deallocation of memory can lead to fragmentation, where
free memory is only available in small non-contiguous blocks. As shown in
@fig:memory_fragmentation, this can cause memory to be exhausted even when the
total free memory is sufficient, as contiguous blocks larger than the fragmented
sizes are not available, leading to Out-Of-Memory (OOM) errors.

#figure(
  align(center)[
    #let b(f, s) = box(width: 0.75em, height: 0.75em, fill: f,
      stroke: s, radius: 2pt)
    #let a() = b(light_blue, 0.75pt + luma(100))
    #let f() = b(white,
      (paint: luma(80), dash: (1.2pt, 1.2pt), thickness: 0.5pt))
    #let n() = b(dark_red, 0.75pt + black)

    #pad(top: 1em, bottom: 0.75em)[
      #pad(bottom: 0.75em)[
        #stack(dir: ltr, spacing: 2em,
          stack(dir: ltr, spacing: 0.5em, a(), align(horizon)[_Used_]),
          stack(dir: ltr, spacing: 0.5em, f(), align(horizon)[_Free_]),
          stack(dir: ltr, spacing: 0.5em, n(), align(horizon)[_New Allocation_])
        )
      ]

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
third-party libraries (e.g. ONNX Runtime).

In addition, the C++ and Rust implementations used `mallinfo2()` to capture the
`fordblks` field, which provides the total size of memory allocated by the
process that is currently free, providing insight into the amount of fragmented
memory that is allocated but not currently in use.

=== System-Wide Memory Tracking

In C++, the global `operator new` and `operator delete` were overridden; in
Rust, a custom `#[global_allocator]` was implemented; and in Python,
`gc.callbacks()` and `sys.getallocatedblocks()` were utilised. Consequently, all
memory allocation metrics were captured at a global level, rather than on a
per-thread or per-sensor basis.

Because the three concurrent telemetry threads operated on independent 1-second
epochs, the memory allocation metrics were slightly desynchronised, resulting in
minor recording variations between the sensor logs. For this reason, only the
RGB telemetry log was used to analyse these metrics. While this introduces a
small desynchronisation between the memory allocation metrics and the IMU
latency measurements, the 1-second epoch is sufficiently long to ensure that the
nanosecond-level desynchronisation is statistically irrelevant.

=== Event Synchronisation

To ensure that identical event streams were processed by each implementation,
without introducing startup jitter or missing initial events, an atomic
variable, `pipeline_stage`, was integrated into each shared memory buffer
header. This variable was set to a value of $1$ (`READY`) by the pipeline
bridges once they were fully initialised and ready to receive data. The load
generator spin-waited until all three pipelines were ready before starting to
push data.

The generator updated the `pipeline_stage` variables to $2$ (`FINISHED`) as each
event stream was completed. Each pipeline bridge processed all remaining valid
frames from the shared memory buffer, and then used a _poison pill_ technique to
signal the end of the stream. A special frame containing a maximum sequence
number (`UINT64_MAX` or `u64::MAX`) was injected into the bounded queue, which
initiated a graceful shutdown of the pipeline by all threads after any pending
frames were processed.

=== Late Fusion

A Multi-Producer Single-Consumer (MPSC) pattern was used to drive the late
fusion, where the inference threads all pushed their results to a single fusion
thread for processing, and the fusion execution was tied to the 30Hz RGB stream.
Anchoring on the slowest, most computationally expensive stream prevented
redundant fusion executions and prevented the fusion thread from being
bottlenecked by the faster IMU streams. Consequently, the IMU streams were both
downsampled using fixed window sizes to match the 30Hz RGB stream, ensuring that
the IMU inference was only executed and the results injected into the MPSC
channel when the window was full. Zero-Order Hold was used to pair the RGB and
IMU inference results, where the most recent IMU inference result was held until
the next RGB inference result was available.

#figure(
  pad(top: 1.0em)[
    #set text(size: 8pt)
    #let n(x, y, t, w) = node((x,y), align(center)[#t], shape: rect, width: w,
    height: 3em)
    #let s(x, y, name, speed) = n(x, y, [*#name*\ $lambda = #speed$], 7.38em)
    #let c(x, y, num) = n(x, y, [Capacity: *#num*], 7.06em)
    #let w(x, y, num) = n(x, y, [Size: *#num*], 9.56em)
    #diagram(
      node-stroke: 0.5pt,
      node-corner-radius: 2pt,
      spacing: (4em, 1.5em),

      node((0, 0), align(top + center)[*Data Streams* \ ($lambda$ Hz)], shape: rect,
      fill: luma(240), width: 7.38em, height: 4.5em),

      node((0, 0), shape: rect, fill: luma(240), width: 7.38em, height: 4.5em,
        align(top + center)[*Data Streams* \ ($lambda$ Hz)]),
      node((1, 0), shape: rect, fill: luma(240), width: 9.86em, height: 4.5em,
        align(top + center)[*Inference Window* \ ($w = lambda div 30$) \ 
          Anchor = 30 Hz]),

      s(0, 1, [RGB], 30),
      s(0, 2, [Accel], 1600),
      s(0, 3, [Gyro], 2000),

      w(1, 1, 1),
      w(1, 2, 53),
      w(1, 3, 66),

      edge((0, 1), (1, 1), "-|>"),
      edge((0, 2), (1, 2), "-|>"),
      edge((0, 3), (1, 3), "-|>"),
      
      edge((0, 0), (0, 1), "-|>", stroke: (dash: "dashed")),
    )
  ],
  caption: [Derivation of the inference window sizes for the IMU streams to
    match the #box[30 Hz] RGB stream, using Zero-Order Hold to pair the
    inference results. #v(0.5em)],
)

==== Power Modes and Cooling

When the Jetson Orin Nano reaches the `hot_surface_alert` trip point of \74°C,
it automatically engages the cooling fan. This is a hardware-level protection
that cannot be disabled. If the fan fails to provide enough cooling, the device
utilises reactive software thermal management (Dynamic Voltage and Frequency
Scaling, or DVFS @jetsonLinuxDeveloperGuide) that constantly polls the
temperature and throttles the performance of the high-power components (e.g. CPU
and GPU) when the device exceeds operating temperature threshold at 99°C (see
@app:thermal-zones).

The Jetson was configured to use the unconstrained power mode (MAXN_SUPER) using
`nvpmodel -m 0`, and maximum clock overrides were enabled using `jetson_clocks`.
This allows the device to operate at its maximum performance. Kernel console
logging was disabled (using `dmesg -n 1`) to prevent I/O interrupts from
affecting the measurements. Temperature, power draw, and clock frequencies were
recorded to a `.log` file using the `tegrastats` utility, and converted to a CSV
file for analysis after the evaluation using `awk`.

The baseline temperature was forced to 55°C by disabling user-space active
cooling (`nvfancontrol`) and stopping the fan by echoing `0` to
`/sys/class/hwmon/hwmon0/pwm1`. The Jetson was then kept busy
(`cat /dev/urandom > /dev/null`) for periods of 2 seconds at a time, until the
baseline temperature was reached or exceeded. The device was then allowed to
idle with the fan speed set to 100% (`255`) until the baseline temperature was
reached again, at which point the fan was stopped and the evaluation started.

Initial attempts to engage DVFS were unsuccessful, as the Jetson's fan was able
to cool the device fast enough to prevent the throttling temperature from being
reached. Therefore, a second evaluation was performed after restricting the
device to the 7-Watt power mode (using `nvpmodel -m 3`), and maximum clock
overrides were disabled (`jetson_clocks`), forcing the device to throttle the
CPU and GPU to adhere to the power budget, thus allowing an evaluation and
comparison of the pipeline under constrained conditions.

#wc[
=== Statistical Analysis

Latency measurements have no theoretical maximum, but are inherently bounded by
a minimum value of zero. This typically results in non-normal distributions
which are heavily skewed to the right, with long tails and outliers @tene2014,
requiring non-parametric methods for statistical analysis. The outliers are
evidence of backpressure events and runtime model pauses (e.g. Garbage
Collection in Python), necessary for benchmarking and implementation
comparisons, and consequently were not removed. Cold start measurements were
analysed separately to prevent them from skewing the measurements of the
steady-state performance. The cold start boundary was determined by calculating
the moving average of the latency measurements and identifying the point at
which the moving average stayed within 5% of the average stabilised latency for
one second.

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
== Methodological Limitations

=== Memory Churn Asymmetry

An asymmetry exists in the measurement of memory churn across the three
implementations. When overriding `operator new` and `operator delete` in C++,
memory allocations made by third-party headers (e.g.
`moodycamel::BlockingConcurrentQueue`) are captured, but allocations made
internally by pre-compiled shared libraries (e.g. `libonnxruntime.so`) are not.
Similarly, in Rust, allocations made by wrapper crates (e.g. `ort`)
are captured, but those in the underlying pre-compiled libraries are not.

While C++, Rust, and Python all use ONNX Runtime's C-API, the Rust wrapper crate
uses a newer version than that used by C++ and Python. Consequently, while all
implementations use the same data structures to serialise data across the
Foreign Function Interface (FFI) boundary, there may be differences in the
memory management of the underlying C-API. An asymmetry also exists in the
capture of memory allocation within Python's third-party C-extension bindings
(e.g. `onnxruntime`), which do not use Python's memory manager and thus are not
visible to the telemetry thread when using `sys.getallocatedblocks()`. While
this asymmetry is a limitation when comparing memory churn across all three
runtime models, the methodology mitigates this by using the RSS as a baseline
that captures all memory demand regardless of its origin.

=== Read-Tearing and Misalignment

Because the shared memory buffer is circular and unbounded, there is a risk that
the producer overwrites a frame while the consumer is reading it, leading to
misalignment or read-tearing of the sensor data. This would be unacceptable in a
production environment, requiring a separate _memory arena_ to store the sensor
data and guarantee that the producer does not overwrite a frame until the
consumer has released it. However, implementing such a solution would
effectively bound the load generator, causing it to block when the pipeline is
saturated, thus reducing the system pressure and hiding the queueing delays that
this report aims to measure.

As the HAR pipeline serves only as a testbed, and the accuracy of the AI
inference does not form a part of the evaluation, the system accepts the
possibility of read-tearing to preserve the unbounded nature of the load
generator. This is minimised by adopting a 1-second ring buffer paired with the
\100 ms latency deadline, building a \900 ms temporal safety margin into the
architecture, which is sufficient to ensure that read-tearing would only be
possible in the event of a major system stall (e.g. an extreme GC
"stop-the-world" pause or severe thermal throttling event).


=== Temporal Alignment of Late-Fusion

The inference window capture-count introduces a temporal misalignment between
the IMU and RGB streams. Because the inference threads construct the temporal
windows by counting the frames, rather than by using timestamp deltas,
aggressive load-shedding effectively stretches the window, causing misalignment
during late-fusion. Furthermore, because the IMU sensor speeds (\1600 Hz and
\2000 Hz) are not wholly divisible by the anchoring RGB sensor speed (\30 Hz),
it is recognised that temporal alignment drift is inevitable even in the absence
of load-shedding.

This would need to be mitigated in a production environment by using a timestamp
delta to bound the temporal window. However, this would introduce a confounder
to this report's evaluation, as the workload would fluctuate according to
language-specific overhead (such as garbage collection pauses in Python).
Therefore, an inference counter was required to allow a true comparison of the
overhead of the three runtime models under identical load conditions.

=== Temporal Alignment of Telemetry

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

=== Static Complexity Analysis

Regarding the code verbosity and complexity analysis, metrics such as LoC and CC
only consider the static source code, and do not consider the learning curve or
cognitive complexity associated with each language (e.g. Rust's borrow checker
and ownership model, C++'s manual memory management, or Python's dynamic
typing). These can all significantly influence the development lifecycle
overhead, and therefore LoC and CC should be interpreted as partial measurements
of the engineering cost of language selection.
]

= Implementation

== System Architecture Overview

To evaluate the language runtime models of C++, Rust, and Python, an identical
multi-threaded HAR pipeline was implemented across all three languages. As shown
in the end-to-end diagram in @fig:end_to_end, individual threads are responsible
for each discrete stage (bridge, inference, late-fusion, and telemetry).
Further, a separate chain of threads is spawned for each unbounded ring buffer
(RGB, accelerometer, and gyroscope), with the exception of the late-fusion
thread, which uses the Multi-Producer Single-Consumer (MPSC) pattern to fuse the
inference results from all three streams into one prediction.

#figure(
  pad(top: 0em)[
    #set text(size: 8pt)

    #let rgb_col = rgb("#FFF4B3")
    #let rgb_grad = gradient.linear(dir: ttb, rgb_col, white)
    #let rgb_grad_inverse = gradient.linear(dir: ttb, white, rgb_col)

    #let accel_col = rgb("FCE7F3")
    #let accel_grad = gradient.linear(dir: ttb, accel_col, white)
    #let accel_grad_inverse = gradient.linear(dir: ttb, white, accel_col)

    #let gyro_col = rgb("#C8BCE0")
    #let gyro_grad = gradient.linear(dir: ttb, gyro_col, white)
    #let gyro_grad_inverse = gradient.linear(dir: ttb, white, gyro_col)

    #let start(x, t, f) = {
      node(enclose: ((x, 0.3), (x, 4.75)), fill: f, stroke: none, layer: -1,
        corner-radius: 4pt)
      node((x, 0.3), [#set text(size: 11pt); *#t*], stroke: none)
    }

    #let end(x, t, f) = {
      node(enclose: ((x, 6.5), (x, 8.7)), fill: f, stroke: none, layer: -1,
        corner-radius: 4pt)
      node((x, 8.7), [#set text(size: 11pt); *#t*], stroke: none)
    }

    #let n(x, y, name, t, f, s) = node((x,y), name: name, align(center)[#t],
      fill: f, shape: s)
    #let r(x, y, name, t) = n(x, y, name, t, pale_green, rect)
    #let c(x, y, name, t) = n(x, y, name, t, pale_blue, cylinder)
    #let e(p1, p2, t, ..args) = edge(p1, p2, "-|>", mark-scale: 175%,
      label: align(center)[#t], label-side: left, label-sep: 0.2em, ..args)
    #let de(p1, p2, t, ..args) = e(p1, p2, t, stroke: (dash: "dashed"), ..args)

    #diagram(
      node-stroke: 0.5pt + charcoal,
      node-corner-radius: 2pt,
      node-inset: 6pt,
      spacing: (50pt, 35pt),

      c(0, 5, <mpsc>, [MPSC\ Channel]),
      r(0, 6, <fusion>, [Late-Fusion\ Thread]),
      e(<mpsc>, <fusion>, [Receive], label-side: center),

      node(enclose: ((-1.4, 2.2), (1.4, 2.7)), corner-radius: 4pt, layer: 0,
        stroke: (paint: rgb("EF4444"), thickness: 1pt, dash: "dashed")),
      node(enclose: ((-1.4, 4.2), (1.4, 6.75)), corner-radius: 4pt, layer: 0,
        stroke: (paint: rgb("3B82F6"), thickness: 1pt, dash: "dashed")),

      start(-1, [RGB], rgb_grad),
      c(-1, 1, <rgb-shm>, [`/dev/shm`\ Ring]),
      r(-1, 2, <rgb-bridge>, [Bridge\ Thread]),
      c(-1, 3, <rgb-bq>, [Bounded\ Queue]),
      r(-1, 4, <rgb-inf>, [Inference\ Threads]),
      r(-1, 7, <rgb-tel>, [Telemetry\ Thread]),
      c(-1, 8, <rgb-csv>, [Telemetry\ CSV]),
      e(<rgb-shm>, <rgb-bridge>, [Spin], label-side: right),
      e(<rgb-bridge>, <rgb-bq>, [Push], label-side: right),
      e(<rgb-bq>, <rgb-inf>, [Pop], label-side: right),
      de(<rgb-inf>, <mpsc>, [Send], label-side: right),
      e(<fusion>, <rgb-tel>, [Record], label-side: right),
      e(<rgb-tel>, <rgb-csv>, [Save], label-side: right),
      end(-1, [RGB], rgb_grad_inverse),

      start(0, [Accel], accel_grad),
      c(0, 1, <accel-shm>, [`/dev/shm`\ Ring]),
      r(0, 2, <accel-bridge>, [Bridge\ Thread]),
      c(0, 3, <accel-bq>, [Bounded\ Queue]),
      r(0, 4, <accel-inf>, [Inference\ Threads]),
      r(0, 7, <accel-tel>, [Telemetry\ Thread]),
      c(0, 8, <accel-csv>, [Telemetry\ CSV]),
      e(<accel-shm>, <accel-bridge>, [Spin], label-side: center),
      e(<accel-bridge>, <accel-bq>, [Push], label-side: center),
      e(<accel-bq>, <accel-inf>, [Pop], label-side: center),
      de(<accel-inf>, <mpsc>, [Send], label-side: center),
      e(<fusion>, <accel-tel>, [Record], label-side: center),
      e(<accel-tel>, <accel-csv>, [Save], label-side: center),
      end(0, [Accel], accel_grad_inverse),

      start(1, [Gyro], gyro_grad),
      c(1, 1, <gyro-shm>, [`/dev/shm`\ Ring]),
      r(1, 2, <gyro-bridge>, [Bridge\ Thread]),
      c(1, 3, <gyro-bq>, [Bounded\ Queue]),
      r(1, 4, <gyro-inf>, [Inference\ Threads]),
      r(1, 7, <gyro-tel>, [Telemetry\ Thread]),
      c(1, 8, <gyro-csv>, [Telemetry\ CSV]),
      e(<gyro-shm>, <gyro-bridge>, [Spin]),
      e(<gyro-bridge>, <gyro-bq>, [Push]),
      e(<gyro-bq>, <gyro-inf>, [Pop]),
      de(<gyro-inf>, <mpsc>, [Send]),
      e(<fusion>, <gyro-tel>, [Record]),
      e(<gyro-tel>, <gyro-csv>, [Save]),
      end(1, [Gyro], gyro_grad_inverse),
    )
  ],

  caption: [End-to-end flow demonstrating data ingestion, backpressure
    application, MPSC synchronisation, late-fusion, and telemetry capture. The
    red dashed region denotes the backpressure application boundary, while the
    blue dashed region highlights the late-fusion execution anchored to the 30
    Hz RGB stream.
  ]
) <fig:end_to_end>

Each spawned thread chain begins at the *Bridge Thread*, which spin-waits on an
unbounded shared memory (`/dev/shm`) ring buffer populated by an external
process, defining the Inter-Process Communication (IPC) boundary. The Bridge
Thread attempts to add ingested frames into a bounded queue, applying the
configured backpressure policy (e.g., Adaptive Decimation, Drop Oldest) to shed
load if the queue is full. The *Inference Thread* pulls frames from the bounded
queue to create temporal event windows, execute the ONNX model, and push the
result to the MPSC channel. The *Late-Fusion Thread* consumes from the MPSC
channel and anchors execution of its ONNX model to the 30 Hz RGB stream, before
finally passing the frames to the individual *Telemetry Threads* for persistence
of the telemetry metrics.

== The Inter-Process Communication (IPC) Boundary

Shared memory (`/dev/shm`) was employed for the unbounded ring buffer, allowing
IPC between the external process and the pipeline implementations. As shown in
@fig:ipc_memory_layout, the buffer's header was sized to 64 bytes with
additional padding to match the size of the Jetson Orin Nano's Cortex-A78AE L1
CPU cache line @a78RefManual, allowing it to remain in a single, isolated cache
line without the risk of false sharing when the adjacent raw frame data was
modified by the producer. In C++ and Rust, this alignment was achieved using
simple compiler directives (`alignas(64)` and `#[repr(C, align(64))]`,
respectively). However, Python required manual memory mapping via
`ctypes.Structure` inheritance to define the byte widths of the fields
(`c_uint32`, `c_uint64`), as shown in @lst:ipc-padding.

#figure(
  pad(top: 0.5em)[
    #let bsq = box(width: 4pt, height: 4pt, fill: rgb("60A5FA"),
      radius: 0.5pt, stroke: 0.25pt + charcoal)

    #let draw_bytes(b) = {
      let cols = if b >= 8 { 8 } else { b }

      grid(
        columns: cols,
        gutter: 2.0pt,
        ..(bsq,) * b
      )
    }

    #let mem(y, h, t, b) = node(
      (0, y), 
      box(width: 100%, height: 100%)[
        #place(top + left)[#t #text(size: 7pt, fill: charcoal)[(#b bytes)]]
        #place(bottom + right)[#draw_bytes(b)]
      ], 
      shape: rect, 
      height: h,
      width: 120pt, 
      fill: luma(252),
      stroke: 0.5pt + charcoal,
      corner-radius: 0pt
    )

    #diagram(
      node-stroke: 0.5pt + charcoal,
      spacing: (0pt, 0pt),

      mem(0, 20pt, [`magic`], 4),
      mem(1, 20pt, [`version`], 4),
      mem(2, 20pt, [`frame_size`], 4),
      mem(3, 20pt, [`capacity`], 4),
      mem(4, 30pt, [`seq_num`], 8),
      mem(5, 30pt, [`stage`], 8),
      mem(6, 45pt, [`padding`], 32),
    )
  ],

  caption: [64-byte aligned IPC memory header layout. Padding ensures\ the
    atomic fields consume exactly one CPU cache line, preventing false sharing.]
) <fig:ipc_memory_layout>

#figure(
  pad(top: 1.0em)[
    ```cpp
      struct alignas(64) ShmHeader {
          uint32_t magic;
          // ... omitted ...
          std::atomic<uint64_t> seq_num;
          std::atomic<uint64_t> pipeline_stage;
      };
      ```
      ```rust
      #[repr(C, align(64))]
      struct ShmHeader {
          pub magic: u32,
          // .. omitted ...
          pub seq_num: AtomicU64,
          pub pipeline_stage: AtomicU64,
      }
      ```
      ```python
      class ShmHeader(ctypes.Structure):
          _fields_ = [
              ('magic', ctypes.c_uint32),
              # ... omitted ...
              ('seq_num', ctypes.c_uint64),
              ('pipeline_stage', ctypes.c_uint64),
              ('_padding', ctypes.c_uint8 * 32),
          ]
      ```
    ],
  caption: [IPC Boundary structure definitions. C++ (top) and Rust
    (middle) use compiler directives for 64-byte alignment. Python (bottom)
    requires manual padding.#v(1em)],
) <lst:ipc-padding>

Mapping the shared memory data to the process's virtual memory address space
provided zero-copy efficiency at the IPC boundary. While this was automatically
handled in Python when instantiating the
`multiprocessing.shared_memory.SharedMemory` class, C++ and Rust both required
manual invocations of the `mmap` native UNIX system function. However, whereas
the raw memory pointers in the compiled languages could be cast directly to the
required structure with no overhead, Python transparently converts the raw
bytes into native Python objects when accessing the fields of the
`ctypes.Structure` @pythonCtypes. This adds CPU overhead that is not present in
the compiled languages.

== Adaptive Decimation Backpressure Policy

When the bounded queue is full, the Bridge Thread uses a configured backpressure
policy (see @sec-backpressure). One policy available to the bridge, Adaptive
Decimation, sheds load at a dynamic rate, while trying to retain temporal
continuity, by downsampling the stream at an increasing rate as the queue enters
a configured "danger zone" (e.g. 80% of queue capacity) _before_ the queue is
full.

As shown in @fig:adaptive_decimation, after reading a frame from the unbounded
ring buffer, the Bridge Thread determines if the length of the bounded queue is
within the danger zone. If so, a decimation ratio value is calculated based on a
linear scale between the minimum and maximum ratios, and how far into the danger
zone the queue length is. A counter is incremented for every frame, and frames
are only pushed to the bounded queue when this counter is wholly divisible by
the ratio. If the push is not successful then the frame is dropped.

#figure(
  pad(top: 0.5em)[
    #set text(size: 7pt)
    
    #let p(x, y, name, t) = node((x,y), name: name, align(center)[#t],
      shape: rect, fill: light_blue, corner-radius: 2pt, inset: 6pt)
    #let d(x, y, name, t) = node((x,y), name: name, align(center)[#t],
      shape: diamond, fill: light_red, inset: 6pt)
    #let io(x, y, name, t) = node((x,y), name: name, align(center)[#t],
      shape: pill, fill: rgb("f3e8ff"), inset: 6pt)
    #let e(p1, p2, ..args) = edge(p1, p2, "-|>", ..args)
    #let yes(p1, p2, ..args) = e(p1, p2, [Yes], label-side: left, ..args)
    #let no(p1, p2, ..args) = e(p1, p2, [No], label-side: right, ..args)

    #diagram(
      node-stroke: 0.5pt + charcoal,
      spacing: (30pt, 30pt),

      io(2, 0, <start>, [Read frame from\ unbounded ring buffer]),
      p(1, 1, <reset>, [Reset counter]),
      d(2, 1, <len>, [Queue length\ $>=$ threshold?]),
      p(2, 2, <ratio>, [Scale `ratio` based\ on danger zone depth]),
      p(2, 3, <inc>, [Increment `counter`]),
      p(3, 3, <drop>, [Drop\ frame]),
      p(1, 4, <push>, [Push to\ Bounded\ Queue]),
      d(2, 4, <mod>, [`counter` divisible\ by `ratio`?]),
      d(1, 5, <success>, [Push\ successful?]),
      p(1, 6, <overwrite>, [Overwrite\ oldest frame]), 

      e(<start>, <len>),
      no(<len>, <reset>),
      yes(<len>, <ratio>),
      e(<ratio>, <inc>),
      e(<inc>, <mod>),
      yes(<mod>, <push>, label-side: right),
      e(<reset>, <push>),
      e(<push>, <success>),

      edge(<mod>, (3, 4), <drop>, "-|>", [No], label-side: left, label-pos: 0.2),
      edge(<drop>, (3, 0), <start>, "-|>"),
      no(<success>, <overwrite>),
      edge(<overwrite>, (0, 6), (0, 0), <start>, "-|>"),
      edge(<success>, (0, 5), (0, 0), <start>, "-|>", [Yes], label-side: right, label-pos: 0.2)
    )
  ],
  caption: [Flowchart detailing the Adaptive Decimation backpressure policy.\
    The algorithm dynamically scales load-shedding based on queue saturation\
    while preserving temporal continuity.]
) <fig:adaptive_decimation>

When implementing this algorithm across the three language runtime models, a
subtle, yet potentially catastrophic, difference was found between the
statically typed languages (C++ and Rust) and the dynamically typed Python.
When calculating the ratio, the statically typed languages naturally truncated
the result of the division to an integer. However, in Python, standard
division (`/`) returns a floating-point value, which caused virtually all frames
to be incorrectly dropped when performing the modulo operation. This subtle
difference highlighted the risk of dynamic typing, and resolving this required
the addition of a second forward-slash character to apply the floor-division
operator (`//`).

== Wait-Free Ingestion

To avoid introducing latency and context-switching overhead, it was necessary to
spin-loop while waiting for new frames at the IPC boundary, without yielding to
the system kernel through the use of OS-level mutexes or sleep instructions. In
C++, a small preprocessor macro was implemented to execute the ARM64 `yield`
assembly instruction, while `std::hint::spin_loop()` was used in Rust. These
_micro-architecture_ hints instruct the CPU to temporarily pause _speculative
execution_ (when the CPU predicts the next instruction and executes it ahead of
time, before the previous instruction has completed) and to throttle the CPU for
a few clock cycles, reducing power usage and generated heat.

Conversely, there is no micro-architectural hint available in Python to yield to
the CPU. Instead, an empty `pass` loop was utilised (see @lst:spin_loop), which
aggressively spins and holds the Global Interpreter Lock (GIL). Though the
Python loop remained functionally identical to the compiled languages, it does
not reduce power usage or heat generation. In addition, because the thread is
spinning in a tight loop, it aggressively holds the Global Interpreter Lock (GIL
--- a mutex that ensures only one Python thread executes at a time), starving
the other threads of execution time and creating an architectural bottleneck.

#figure(
  pad(top: 1em)[
    ```cpp
    #if defined(__x86_64__) || defined(_M_X64)
      #include <immintrin.h>
      inline void spin_loop() { _mm_pause(); }
    #elif defined(__aarch64__)
      inline void spin_loop() {
        __asm__ volatile("yield" ::: "memory");
      }
    #else
      inline void spin_loop() {}
    #endif
    ```
    ```rust
    loop {
      if seq_num > self.frame_idx {
          return frame;
      }

      std::hint::spin_loop();
    }
    ```
    ```python
    while True:
        if seq_num > self.frame_idx:
            return frame
        pass
    ```
  ],
  caption: [Wait-free spin-loop implementations. C++ (top) and Rust (middle) use
    micro-architectural hints to pause execution. Python (bottom) instead relies
    on an empty `pass` loop that holds the Global Interpreter Lock (GIL).
    #v(1em)]
) <lst:spin_loop>

== Channels

Channels were required to enable communication between the inference and
late-fusion threads, and the late-fusion and telemetry threads. The former uses
a Multi-Producer Single-Consumer (MPSC) channel --- multiple producers (the
inference threads) push data into the channel to be pulled by one consumer (the
late-fusion thread). The latter uses a Single-Producer Single-Consumer (SPSC)
channel --- one producer (the late-fusion thread) pushes data into the channel,
to be pulled by one consumer (the telemetry thread).

Rust provides a memory-safe bounded channel via `std::sync::mpsc`. However,
C++ required a third-party library (moodycamel::BlockingConcurrentQueue).
Because this implementation is unbounded and dynamically allocates memory to
grow, a `std::counting_semaphore` was utilised to enforce a maximum capacity,
satisfying the zero-allocation pipeline requirement.

The Python channel implementation utilised the standard library's
`queue.Queue`. This class uses mutexes to lock the queue, preventing thread
contention each time an attempt is made to push or pull from the channel. This
constant locking and unlocking introduces context-switching (which in turn
introduces latency and jitter), and thrashes the GIL, degrading performance of
other threads as they are starved of execution time.

=== Bounded Queue Locking

The bounded buffer queue is shared between the bridge and inference threads ---
the former pushes data into the queue, and the latter pops data from it. This
required the use of a mutex lock to enforce memory safety and to guarantee
mutual exclusion. In C++ and Python, the locks were implemented as member
variables of the `Queue` class (`std::mutex` and `threading.Lock`,
respectively). While C++ uses Resource Acquisition Is Initialisation (RAII),
and Python uses a context manager to set up and tear down the mutex
automatically, neither offers enforced linking of the lock to the queue.
Conversely, Rust's `std::sync::Arc<Mutex<T>>` combines compiler-enforced RAII
and data ownership, guaranteeing that the queue cannot be accessed without first
acquiring the lock guard.

=== Zero-Allocation Telemetry

To prevent the telemetry thread from becoming a confounder of the results that
are being measured (i.e. the "observer effect"), it was designed to be
zero-allocation and non-blocking.

Triple-buffering was implemented to exchange the telemetry epoch from the hot
thread to the telemetry thread. As demonstrated in @lst:triple-buffering, a
pointer to the active epoch is swapped with a pointer to a clean epoch, with no
I/O latency or dynamic memory allocation.

#figure(
  pad(top: 1em)[
    ```cpp
    void
    TelemetryWriter::swap_buffers()
    {
      auto next_epoch_opt = receiver_.try_receive();

      if (next_epoch_opt.has_value()) {
        last_swap_ = std::chrono::steady_clock::now();
        sender_.send(std::move(current_epoch_));
        current_epoch_ = std::move(next_epoch_opt.value());
      }
    }
    ```
    ```rust
    fn swap_buffers(&mut self) -> Result<()> {
      if let Ok(mut epoch) = self.receiver.try_recv() {
        self.last_swap = Instant::now();
        std::mem::swap(&mut self.current_epoch,
          &mut epoch);
        self.sender.send(epoch)?;
      }
      Ok(())
    }
    ```
    ```python
    def swap_buffers(self):
        epoch = self.receiver.try_receive()
        if epoch != None:
            self.last_swap = time.perf_counter_ns()
            self.sender.send(self.current_epoch)
            self.current_epoch = epoch
    ```
  ],
  caption: [The C++ (top), Rust (middle), and Python (bottom) implementations of
    the zero-allocation telemetry thread buffer swap. The hot thread pushes the
    current epoch to the telemetry thread, and swaps in a clean epoch for the
    next telemetry cycle.#v(1em)]
) <lst:triple-buffering>

To measure memory efficiency without the overhead of third-party tools, the C++
and Rust memory allocators were overridden. As shown in @lst:memory-alloc, the
global memory allocation and deallocation functions were overridden, and relaxed
memory ordering used to prevent unnecessary stalls of the pipeline.

#figure(
  pad(top: 1em)[
    ```cpp
    void*
    operator new(std::size_t count)
    {
      telemetry::allocated_bytes.fetch_add(count,
        std::memory_order_relaxed);
      telemetry::allocation_count.fetch_add(1,
        std::memory_order_relaxed);

      if (void* ptr = std::malloc(count)) {
        return ptr;
      }

      throw std::bad_alloc{};
    }

    void
    operator delete(void* ptr, std::size_t count) noexcept
    {
      telemetry::freed_bytes.fetch_add(count,
        std::memory_order_relaxed);
      std::free(ptr);
    }
    ```
    ```rust
    unsafe impl GlobalAlloc for TrackingAllocator {
      unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        ALLOCATED_BYTES.fetch_add(layout.size(),
          Ordering::Relaxed);
        ALLOCATION_COUNT.fetch_add(1, Ordering::Relaxed);
        unsafe { System.alloc(layout) }
      }

      unsafe fn dealloc(&self, ptr: *mut u8,
        layout: Layout) {
        FREED_BYTES.fetch_add(layout.size(),
          Ordering::Relaxed);
        unsafe { System.dealloc(ptr, layout) }
      }
    }

    #[global_allocator]
    static GLOBAL: TrackingAllocator = TrackingAllocator;
    ```
  ],
  caption: [Overriding the global memory allocation and deallocation functions
    in C++ (top) and Rust (bottom) to capture memory allocation metrics.#v(1em)]
) <lst:memory-alloc>

To measure Python's garbage collection (GC) jitter, the GC callback hook was
utilised, as shown in @lst:gc-callback. This allows the duration of
"stop-the-world" events to be measured without the overhead of `tracemalloc` or
other monitoring tools.

#figure(
  pad(top: 1em)[
    ```python
    def gc_callback(phase, info):
      global pause_ns

      if phase == "start":
        _state["start_time"] = time.perf_counter_ns()
      elif phase == "stop":
        pause_ns += (time.perf_counter_ns() -
          _state["start_time"])

    gc.callbacks.append(gc_callback)
    ```
  ],
  caption: [Capturing the duration spent in the Python Garbage \
    Collector (GC) using the `gc.callbacks` hook.#v(1em)]
) <lst:gc-callback>
]
#pagebreak()
#columns(1)[

#wc[
= Results

To prevent cold-start initialisation from skewing the steady-state measurements,
the first 10 seconds of all telemetry logs were excluded from the diagrams and
analyses unless otherwise stated. Similarly, unless other stated all evaluations
were performed in MAXN_SUPER power mode (`nvpmodel -m 2`).

== Baseline Performance (MAXN_SUPER) <sec:baseline-performance>

With MAXN SUPER mode enabled (@fig:MAXN_SUPER-baseline-performance), C++
sustained ingestion without absolute saturation up to a `load` multiplier of
\4.0 for the Bounded Queue policy, and \5.5 for Exponential Backoff. Rust was
able to process both flow control policies at \5.5. For the load shedding
policies (Drop Oldest and Drop Newest) and Adaptive Decimation, both compiled
languages were able to process the data streams at \1.0, but reached absolute
saturation at higher `load` multipliers.

Conversely, Python was only able to process the data streams at \5% (`load`
multiplier of \0.05) when Exponential Backoff was used. Absolute saturation was
reached at < \0.01 for all other backpressure policies.

#figure(
  pad(top: 0em)[
    #image("code/results/img/MAXN_SUPER-baseline-performance.pdf", width: 85%)
  ],
  caption: [Absolute pipeline saturation points for each language and
    backpressure policy. #v(2em)],
) <fig:MAXN_SUPER-baseline-performance>

The \99.9th percentile latency distribution was analysed using the Exponential
Backoff backpressure policy, when every implementation was at its most efficient
(@fig:MAXN_SUPER-cdf-5_5). This represents the maximum measured throughput
sustained by both compiled languages, without breaching the \100 ms latency
deadline. Despite using the same backpressure policy, and not dropping any
frames, Python consistently breached the deadline --- typically operating at
several times slower than required, and with a maximum latency of \778.0 ms.

#figure(
  pad(top: 1em)[
    #image("code/results/img/MAXN_SUPER-latency-5.5.pdf", width: 85%)
  ],
  caption: [CDF of \99.9th percentile total latency for each language at `load`
    \5.5, using the Exponential Backoff backpressure policy.],
) <fig:MAXN_SUPER-cdf-5_5>

#colbreak()

The \99.9th latency distribution was also analysed using the Exponential Backoff
backpressure policy at a `load` multiplier of \7.0 (@fig:MAXN_SUPER-cdf-7_0) ---
the lowest measured throughput at which the compiled languages breached the 100
ms latency deadline. Python was omitted as its maximum throughput measured
without breaching the deadline was at a `load` multiplier of \0.05, making it
incomparable when `load` is increased to \7.0.

While the flow-control policy does prevent data loss (until the 1-second unbound
circular buffer laps), it does so at the cost of increased queue accumulation
and increasing the actual latency beyond the \100 ms deadline. \76.9% of the C++
epochs breached the deadline with a maximum latency of \173.7 ms, compared to
\56.5% of the Rust epochs with a maximum latency of \171.2 ms.

#figure(
  pad(top: 1em)[
    #image("code/results/img/MAXN_SUPER-latency-7.0.pdf", width: 85%)
  ],
  caption: [CDF of \99.9th percentile total latency for both compiled languages
    at `load` \7.0, using the Exponential Backoff backpressure policy. #v(5em)],
) <fig:MAXN_SUPER-cdf-7_0>

== Individual Stream Saturation

Using the Exponential Backoff policy, the individual sensor streams were
analysed to determine the maximum `load` multiplier that each stream could
sustain without dropping frames. As a whole, both compiled implementations
achieved a maximum `load` of \5.5 (@sec:baseline-performance).

As demonstrated in @fig:MAXN_SUPER-stream-saturation, this failure is isolated
to the RGB stream. While the pipelines began to drop frames from the \30 Hz RGB
stream when the `load` exceeded \5.5, both the \1.6 kHz Accelerometer stream and
\2.0 kHz Gyroscope stream successfully sustained ingestion without data loss up
to the maximum tested `load` multiplier of \8.5.

#figure(
  pad(top: 1em)[
    #image("code/results/img/MAXN_SUPER-stream-saturation.pdf", width: 85%)
  ],
  caption: [Maximum `load` multiplier sustained by each individual stream
    without dropping frames, using the Exponential Backoff backpressure
    policy.],
) <fig:MAXN_SUPER-stream-saturation>

#colbreak()

== Latency Breakdown

The overall pipeline latency was broken down into its five stages, and the
average median (p50) calculated. Summing the deep tail percentiles (e.g. the
\99.9th) across all stages would be misleading, as it would assume that the
worst-case latency of each stage occurs for a single frame, which would
misrepresent the actual latency of the typical frame. The Exponential Backoff
policy was selected, with a `load` of \0.05, as this was the maximum throughput
speed that all three implementations were able to sustain without dropping
frames.

As @fig:MAXN_SUPER-latency-breakdown shows, C++ and Rust both completed the
pipeline well within the \100 ms deadline (\7.8 ms and \7.3 ms respectively),
with the Inference Execution stage taking the majority of that time (\5.9 ms for
C++, and \5.2 ms for Rust). Conversely, Python's total average median latency
breached the \100 ms deadline (\105.2 ms), with the majority of that time spent
with frames waiting in the unbounded circular buffer (\31.9 ms) or the bounded
queue buffer (\28.2 ms). The Inference Execution stage (\22.5 ms) was also
significantly slower than the compiled languages.

#figure(
  pad(top: 1em)[
    #image("code/results/img/MAXN_SUPER-latency-breakdown.pdf", width: 85%)
  ],
  caption: [Stage-by-stage median (p50) latency breakdown for the RGB stream at
    `load` \0.05 using the Exponential Backoff backpressure policy.],
) <fig:MAXN_SUPER-latency-breakdown>

== Flow Control vs. Load Shedding

To compare the total number of dropped or lapped frames between flow-control and
load-shedding policies, the most efficient flow-control policy (Exponential
Backoff) was contrasted against the two most pure load-shedding policies: Drop
Oldest and Drop Newest. These policies both drop frames when the bounded queue
is full, without trying to prevent it filling to capacity by dynamically
adjusting the flow-rate. Rust was the most efficient implementation, and so was
selected for this comparison. A `load` multiplier of \2.5 was used as it is the
lowest measured multiplier at which both load-shedding policies dropped frames.

As shown in @fig:MAXN_SUPER-dropped-frames, the Exponential Backoff flow-control
policy was able to fully absorb the latency jitter by taking advantage of the
\1-second unbounded buffer. In contrast, the load-shedding policies dropped
frames to maintain the \100 ms latency deadline. The Drop Newest policy recorded
a total of \21 dropped frames over the \600 second evaluation period, while the
Drop Oldest policy recorded \56 dropped frames.

#figure(
  pad(top: 0.5em)[
    #image("code/results/img/MAXN_SUPER-dropped-frames.pdf", width: 85%)
  ],
  caption: [Total dropped frames for Rust at `load` \2.5, comparing the
    Exponential Backoff \
    flow-control policy against the Drop Oldest and Drop Newest load-shedding
    policies. #v(2em)],
) <fig:MAXN_SUPER-dropped-frames>

#colbreak()

While flow-control policies excel at preventing data-loss when experiencing
jitter, load-shedding policies sacrifice the data to meet the latency deadline.
As shown in @fig:MAXN_SUPER-latency-comparison, the impact of retaining stale
data to prevent loss caused forced the majority of epochs (\56.5%) to breach the
100 ms latency deadline. Conversely, by dropping frames and preventing a growing
backlog, the load-shedding policies guarantee that surviving frames are
processed within the deadline.

#figure(
  pad(top: 0.5em)[
    #image("code/results/img/MAXN_SUPER-latency-comparison.pdf", width: 85%)
  ],
  caption: [Latency comparison for Rust at `load` \7.0, comparing the
    Exponential Backoff \
    flow-control policy against the Drop Oldest, Drop Newest, and Adaptive
    Decimation. #v(2em)],
) <fig:MAXN_SUPER-latency-comparison>

To mitigate the temporal data loss characteristic of load-shedding policies,
while also avoiding the fast growth of stale frames within the unbounded buffer,
the Adaptive Decimation policy was compared. By dynamically downsampling the
incoming stream before the bounded buffer reaches full capacity, the policy
reduces volume pressure while maintaining temporal continuity. However,
preserving the temporal continuity sacrifices a substantial number of frames ---
\675 frames were dropped over the 600 second evaluation period (not shown in
@fig:MAXN_SUPER-dropped-frames to preserve visual clarity). In addition, total
latency increased compared to the Drop Oldest policy, though was lower than that
achieved by Drop Newest. Because Adaptive Decimation and Drop Newest both drop
incoming frames, the existing frames in the bounded buffer continue to age while
waiting to be processed. Conversely, Drop Oldest drops the oldest data from the
bounded buffer, guaranteeing that the freshest data survives.

#colbreak()

== Memory Overhead <sec:memory-overhead>

To investigate the impact of Python's automated memory management on deadline
adherence, the maximum latency was plotted for all three implementations,
alongside the recorded duration of Python's Garbage Collection (GC) pauses. A
`load` multiplier of \0.05 was selected, with a policy of Exponential Backoff,
as this was the maximum throughput measured that all three implementations were
able to sustain without the loss of data. The initial 60-second window, as
illustrated in @fig:MAXN_SUPER-python-gc, captures the initialisation phase and
the subsequent steady-state, while retaining visual clarity.

C++ and Rust demonstrated stable maximum latencies below the 100 ms deadline
during the initialisation phase (\27.5 ms and \34.0 ms, respectively) and the
subsequent steady-state phase (\36.8 ms and \46.1 ms, respectively), with ranges
of \14.2 ms and \20.0 ms respectively during initialisation, and \32.0 ms and
\41.4 ms respectively during steady-state.

During the initialisation phase, Python exhibited a maximum latency of \683.1
ms, with a range of \636.6 ms. During the subsequent steady-state phase, maximum
latency increased to \2,652.9 ms, and the latency range increased to \2,627.3
ms. Python's "stop-the-world" GC events were confined to only the first few
seconds of the \60-second window. This was confirmed by a Spearman's rank
correlation across the steady-state window, which produced an undefined result
(`NaN`) due to no GC events occurring during that time.

#figure(
  pad(top: 1.5em)[
    #image("code/results/img/python_gc_jitter.pdf", width: 85%)
  ],
  caption: [Maximum latency vs. GC pause duration over the first \60 seconds
    of execution. #v(3.5em)],
) <fig:MAXN_SUPER-python-gc>

To further evaluate the resource efficiency of the runtime models, the Resident
Set Size (RSS) was measured under the heaviest load conditions that both
compiled languages were able to sustain without dropping frames (Exponential
Backoff, `load` \5.5).

As demonstrated in the left panel of @fig:MAXN_SUPER-memory-profiling, the
overall memory footprint remained consistent across all three implementations,
with C++, Rust, and Python stabilising at approximately \743.2 MB, \746.5 MB,
and \782.0 MB respectively.

The right panel of @fig:MAXN_SUPER-memory-profiling demonstrates the cumulative
dynamic memory allocations of the C++ and Rust implementations in the pipeline.
Following the 10-second initialisation phase, there was no dynamic memory
allocation for either implementation.

#figure(
  pad(top: 2.5em)[
    #image("code/results/img/MAXN_SUPER-memory-profiling.pdf", width: 95%)
  ],
  caption: [Memory profiling during steady-state execution. The left
    panel compares the Resident Set Size (RSS) footprint. \
    The right panel shows the total dynamic memory allocations by the C++ and
    Rust implementations. #v(3.5em)],
) <fig:MAXN_SUPER-memory-profiling>


Heap fragmentation using the `fordblks` field from `mallinfo2()` was also
measured to evaluate the long-term stability of the runtime models and the
effectiveness of the zero-allocation architecture. The recorded telemetry showed
that heap fragmentation was negligible for both C++ (\8.2 KB) and Rust (\9.9
KB). Both coupled with RSS footprints of over \740 MB, and steady-state dynamic
allocation rates of \0.0 Bytes/second, this proves that both implementations
were able to sustain the load without memory churn or fragmentation.

#colbreak()
== Thermal Accumulation

During the evaluations, the Jetson Orin Nano's emergency fan cooling prevented
DVFS frequency scaling by engaging the fan at \74°C. However, analysis of the
`tegrastats` telemetry revealed thermal accumulation differences between the
runtime models.

Figure @fig:MAXN_SUPER-thermals-native shows all three implementations subject
to the natural stream rate (`load` \1.0) using the Exponential Backoff
backpressure policy. C++ triggered the fan after \152 seconds, Rust at \179
seconds, and Python at \180 seconds. By the end of the evaluation, the C++
temperature had reached a steady-state approximately \4°C hotter than Rust, and
\5°C hotter than Python.

#figure(
  pad(top: 1em)[
    #image("code/results/img/MAXN_SUPER-thermals-native.pdf", width: 85%)
  ],
  caption: [Thermal accumulation at the natural stream rate using the
    Exponential Backoff backpressure policy. #v(2em)],
) <fig:MAXN_SUPER-thermals-native>

@fig:MAXN_SUPER-thermals-saturated plots the temperature curves of each
implementation at their respective maximum measured saturation points
(Exponential Backoff, `load` \5.5 for the compiled languages, and \0.05 for
Python). At maximum throughput, C++ and Rust triggered the fan after \91 seconds
and \100 seconds respectively. The temperatures then settled to approximately
\68.5°C and \67°C respectively. Conversely, at the maximum sustainable `load`
multiplier of \0.05, the fan did not trigger for Python until \166 seconds, and
the temperature then settled to approximately \57°C.

#figure(
  pad(top: 1em)[
    #image("code/results/img/MAXN_SUPER-thermals-saturated.pdf", width: 85%)
  ],
  caption: [Thermal accumulation at the maximum sustainable throughput using the
    Exponential Backoff backpressure policy.],
) <fig:MAXN_SUPER-thermals-saturated>
]

#colbreak()

#columns(2, gutter: 16pt)[
= Discussion

== Compilation Times

Despite Rust's stricter compile-time checks and safety guarantees (e.g.
ownership, the borrow checker, and strict variable usage), compilation times
were significantly faster than experienced with C++. The latter implementation
relies on several template classes --- both standard (e.g. `std::shared_ptr`,
`std::vector`) and pipeline specific (the channel `Sender`/`Receiver` and the
`Queue`). By language design, C++ templates must be defined in header files, and
because C++ relies on a pre-processor source file inclusion model (`#include`),
these headers are copied into every Translation Unit (TU) that references them,
forcing the compiler to repeatedly parse the same templates across multiple TUs.

Conversely, Rust's compiler does not rely on source file inclusion, and instead
parses each crate only once (regardless of how many modules reference it),
preventing an accumulation of unnecessary parsing overhead. Furthermore the
cargo build tool caches a project dependency graph of to avoid re-parsing or
re-compiling unchanged files.

In contrast to C++ and Rust, Python is an interpreted language and consequently
has no compilation overhead, thus reducing friction during initial prototyping.
However, errors that the other languages would catch at compile time are only
discovered at runtime in Python, risking reduced system stability within the
production environment.

It is worth noting that while Rust's memory management philosophy might be
considered to sit somewhere between the developer-responsibility paradigm of C++
and the garbage-collected paradigm of Python, Rust developers benefit from fast
compilation times, and the only paradigm under evaluation that guarantees memory
safety before runtime. This is a significant advantage when developing and
maintaining large, complex systems.

== Error Handling

Rust's `Result` type forces developers to explicitly handle failure states at
compile time. The `?` propagation operator offers a concise mechanism to push
errors up the call stack without complicating the primary logic flow. These
language paradigms dramatically simplify the error-handling code, and allow the
adoption of boilerplate-reducing third-party crates (e.g. `anyhow`) to add error
handling and contextual information in one expression.

In contrast, both the C++ and Python implementations rely on developer
discipline to write verbose error handling code to explicitly handle exceptions
(`try`/`catch` and `try`/`except`) and legacy error codes, risking the
occurrence of unhandled errors (decreasing system stability), and a lack of
contextual information when debugging (increasing system maintenance overhead).

There is a clear contrast when comparing Rust's return type and the
exception-based error handling of C++ and Python. Rust's `?` operator, in
combination with third-party crates such as `anyhow`, allow developers to add
fine-grained contextual information to errors without any boilerplate code.
Achieving this same level of granularity in C++ or Python would require a
try-block (`try`/`catch` or `try`/`except`) around every invocation of a
function that may throw an exception. This would severely hamper code
readability and maintainability, and therefore idiomatic C++ and Python
implement coarser-grained exception handling, at the sacrifice of diagnostic
information when an error occurs.

== Language Ergonomics

While static analysis tools such as Lizard provide a quantitative evaluation for
Lines of Code (LoC) and Cyclomatic Complexity (CC), they do not consider the
qualitative experience of the developer when writing and maintaining code. The
implementation of the three pipelines revealed significant differences in
language ergonomics and the resulting cognitive load. Both Rust and Python
provide simple mechanisms for transforming data collections and evaluating
enumeration types (such as Rust's `match` operator), requiring minimal
boilerplate code and improving code readability.

While C++ has evolved over successive versions to offer similar functionality
via the standard library (e.g. `std::ranges` and `std::transform` for
collections, or `std::variant` and `std::visit` for enumerations), utilising
these features was counterproductive. For example, introducing transformations
to data collections introduced verbosity and code complexity. Consequently,
traditional `for` loops were used instead to maintain code readability, and to
reduce maintenance overhead.

Similarly, pattern matching in C++ required the use of `std::visit`, which
introduced syntactic complexity that made the code difficult to read. The code
formatter struggled to parse the code coherently, requiring
`// clang-format off` directives to maintain legibility. This demonstrates that
the complexity of C++'s legacy architecture and backward compatibility can deter
the adoption of attempts to introduce modern approaches to software development,
forcing developers to revert to a more traditional style of programming.

== Ecosystem Maturity and Deployment

The C++ ecosystem is a highly cohesive, mature development environment. Its
foundation libraries have remained stable for years, with a strong adherence to
backwards compatibility offering long-term stability and reducing long-term
maintenance overhead.

While Rust's `cargo` build tool offers easy-to-use package management, the
maturity of the ecosystem is still evolving. In contrast to C++, many of Rust's
foundation libraries (e.g. `libc`, `nix`) remain in "zerover" (0.x.y)
pre-release states. This results in a cognitive burden caused by API changes,
deprecated or incomplete documentation, and conflicting online resources.

Furthermore, whereas C++ uses system-installed shared libraries, meaning they
are _layer cached_ early in the Docker image build process, Rust's `cargo`
downloads and compiles all dependencies during the build process, resulting in
extended deployment times. Circumventing this required dummy source files to be
created (with an identical `Cargo.toml` manifest) to allow a layer to be cached
early, thus mitigating download-and-compile overhead during every deployment. It
was also necessary to artificially update the modification timestamps of the
real source files to guarantee that the later `cargo build` command would
recompile the source files, rather than using the cached dummy executables.

Python's large ecosystem accelerates initial prototyping, but introduces
friction during deployment. While C++ and Rust compile down to stand-alone
executable files which can be easily deployed to the target hardware, Python's
interpreted nature demands deployment of the Python interpreter itself, the
source files, and an identical virtual environment. This results in Python
deployment being heavier, more complex, and more fragile than the statically
compiled counterparts. Furthermore, Python's package management system was found
to be fragile. Package versions had to be manually pinned (by referring to the
Python Package Index (PyPI) release history @pypi) to prevent versions being
automatically selected that were incompatible with the Python interpreter under
evaluation (Python \3.10.12). In addition, the ONNX Runtime package for the
Jetson Orin Nano is remotely hosted on NVIDIA's PyPi server @pypi_devpi, which
was often found to be unavailable, requiring the package to be manually
downloaded and saved locally for adding to the Docker image later.

== Concurrency and Memory Safety

A clear contrast was experienced between the manual memory management of C++ and
the compiler-enforced memory safety of Rust. Spawning threads using
`std::jthread` in C++ relies on lambda expressions, which allows variables to be
captured by reference (e.g. `[&receiver]`). While concise and convenient for
developers, this creates a dangling reference if the spawned thread uses the
captured variable after the variable's enclosing scope has ended. Because the
C++ compiler does not check for memory safety issues, this error is not flagged
to the developer. Therefore, avoiding such errors relies on developer discipline
and vigilance, which becomes an increasingly difficult burden as the size and
complexity of the codebase grows.

Conversely, Rust's ownership model and borrow checker guarantees memory safety.
In the aforementioned example, the Rust compiler would refuse to allow
references that may not outlive the spawned thread. Instead, Rust forces the
developer to transfer ownership using the `move` keyword and atomic reference
counting (e.g. `Arc<Mutex<T>>`). Though Rust's ownership model may be a steep
learning curve for developers new to the language --- similar to that
experienced when transitioning from a functional paradigm to an object-oriented
one --- it eliminates memory-safety bugs that are notoriously difficult to
resolve, shifting the burden from developer discipline and vigilance to compiler
analysis.

Python's GC automatically handles the lifetime of the variable, preventing the
dangling reference vulnerabilities of C++, without the steep learning curve of
Rust's borrowing mechanism.

== Memory Management Friction

It is generally believed that a runtime model Garbage Collector (GC) reduces
cognitive burden when compared to manual memory management (C++), or an
ownership model (Rust). However, the opposite was found to be true when
developing the temporal buffering of the unbounded queue's frame payloads. For
example, to circumvent premature unmapping of shared memory buffer addresses
when the bridge thread terminates and the inference thread is still processing
frames, a memory location offset had to be provided in the Python frames instead
of physical addresses as used in the C++ and Rust implementations. The Python
inference threads also had to maintain a second
`multiprocessing.shared_memory.SharedMemory` object to read the frame payloads.
Doing so caused a further issue of `KeyError` tracebacks displayed during
evaluation, requiring `noop` patching of the `resource_tracker.register` and
`unregister` methods.

Conversely, C++ stipulates that the developer is responsible for all memory
allocation and deallocation. Consequently a frame's payload address can be
stored directly in the frame itself, with no friction or risk of premature
unmapping. Rust's ownership model also prevents premature unmapping, but
`unsafe` marker traits (`Send` and `Sync`) were required to satisfy the compiler
and allow the memory addresses to be shared across threads.

== Asymmetrical Stream Saturation

Analysis of the individual data streams of the compiled implementations revealed
a significant difference in the maximum sustainable ingestion speed, with the
RGB stream failing at a `load` multiplier of \7.0, and the Accelerometer and
Gyroscope streams not dropping or lapping any frames at the maximum measured
`load` multiplier of \8.5.

Little's Law ($L = lambda W$) was used to enforce the \100 ms end-to-end latency
deadline. Because the RGB stream's native speed is low at \30 Hz, its bounded
buffer capacity is only \3 frames. In contrast, the \1.6 kHz Accelerometer
stream buffer has a capacity of \160 frames, and the \2.0 kHz Gyroscope stream
buffer has a capacity of \200 frames. Consequently, these high-frequency stream
buffers have more elasticity to absorb latency spikes, while the RGB stream
buffer is almost immediately saturated.

This asymmetry is exacerbated by both the inference thread and the late-fusion
thread --- the latter of which uses a Multi-Producer Single-Consumer (MPSC)
channel anchored to the RGB stream. While the Accelerometer and Gyroscope
inferences only occur every \53 and \66 frames respectively, inference is
triggered for every RGB frame, which in turn triggers late-fusion, substantially
increasing the average workload per frame for the RGB stream.

When the pipeline processes a high enough ingestion rate, the late-fusion thread
will struggle to process the inference results from the MPSC channel. This
causes the inference threads to block while attempting to push their results
into the saturated channel. Because each frame in the IMU bounded buffers
represent a shorter period of time, and each buffer represents the same period
of time, the IMU buffers have the flexibility to absorb the temporary MPSC
blockage without dropped or lapped frames. Conversely, because the RGB bounded
buffer has a capacity of only \3 frames, each of which represents a longer
period of time, the RGB bounded buffer is quickly saturated. This triggers the
active backpressure policy, resulting in dropped or lapped frames, and/or the
latency deadline to be breached.

Ultimately, this demonstrates that in Edge-AI pipelines, the synchronisation
anchor forms the bottleneck that dictates the maximum capacity and stability of
the system as a whole.

= Conclusion

Total words: #total-words

#columns(1)[
#counter(heading).update(0)
#set heading(numbering: "A.1", supplement: [Appendix])

= Hardware Power Profiles <app:power-profiles>

Raw configuration output from the Jetson Orin Nano `nvpmodel` daemon, detailing
core availability, and minimum and maximum caps for all power modes.

```text
NVPM VERB: Config file: /etc/nvpmodel.conf
NVPM VERB: parsing done for /etc/nvpmodel.conf
succeed to parse file /etc/nvpmodel.conf.
NVPM VERB: PM_CONFIG: DEFAULT=25W(1)
NVPM VERB: PARAM TYPE=FILE NAME=CPU_ONLINE
NVPM VERB: CORE_0 /sys/devices/system/cpu/cpu0/online
NVPM VERB: CORE_1 /sys/devices/system/cpu/cpu1/online
NVPM VERB: CORE_2 /sys/devices/system/cpu/cpu2/online
NVPM VERB: CORE_3 /sys/devices/system/cpu/cpu3/online
NVPM VERB: CORE_4 /sys/devices/system/cpu/cpu4/online
NVPM VERB: CORE_5 /sys/devices/system/cpu/cpu5/online
NVPM VERB: PARAM TYPE=FILE NAME=FBP_POWER_GATING
NVPM VERB: FBP_PG_MASK /sys/devices/platform/gpu.0/fbp_pg_mask
NVPM VERB: PARAM TYPE=FILE NAME=TPC_POWER_GATING
NVPM VERB: TPC_PG_MASK /sys/devices/platform/gpu.0/tpc_pg_mask
NVPM VERB: PARAM TYPE=FILE NAME=GPU_POWER_CONTROL_ENABLE
NVPM VERB: GPU_PWR_CNTL_EN /sys/devices/platform/gpu.0/power/control
NVPM VERB: PARAM TYPE=FILE NAME=GPU_POWER_CONTROL_DISABLE
NVPM VERB: GPU_PWR_CNTL_DIS /sys/devices/platform/gpu.0/power/control
NVPM VERB: PARAM TYPE=CLOCK NAME=CPU_A78_0
NVPM VERB: FREQ_TABLE /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies
NVPM VERB: MAX_FREQ /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
NVPM VERB: MIN_FREQ /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
NVPM VERB: PARAM TYPE=CLOCK NAME=CPU_A78_1
NVPM VERB: FREQ_TABLE /sys/devices/system/cpu/cpu1/cpufreq/scaling_available_frequencies
NVPM VERB: MAX_FREQ /sys/devices/system/cpu/cpu1/cpufreq/scaling_max_freq
NVPM VERB: MIN_FREQ /sys/devices/system/cpu/cpu1/cpufreq/scaling_min_freq
NVPM VERB: PARAM TYPE=CLOCK NAME=CPU_A78_2
NVPM VERB: FREQ_TABLE /sys/devices/system/cpu/cpu2/cpufreq/scaling_available_frequencies
NVPM VERB: MAX_FREQ /sys/devices/system/cpu/cpu2/cpufreq/scaling_max_freq
NVPM VERB: MIN_FREQ /sys/devices/system/cpu/cpu2/cpufreq/scaling_min_freq
NVPM VERB: PARAM TYPE=CLOCK NAME=CPU_A78_3
NVPM VERB: FREQ_TABLE /sys/devices/system/cpu/cpu3/cpufreq/scaling_available_frequencies
NVPM VERB: MAX_FREQ /sys/devices/system/cpu/cpu3/cpufreq/scaling_max_freq
NVPM VERB: MIN_FREQ /sys/devices/system/cpu/cpu3/cpufreq/scaling_min_freq
NVPM VERB: PARAM TYPE=CLOCK NAME=CPU_A78_4
NVPM VERB: FREQ_TABLE /sys/devices/system/cpu/cpu4/cpufreq/scaling_available_frequencies
NVPM VERB: MAX_FREQ /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq
NVPM VERB: MIN_FREQ /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
NVPM VERB: PARAM TYPE=CLOCK NAME=CPU_A78_5
NVPM VERB: FREQ_TABLE /sys/devices/system/cpu/cpu5/cpufreq/scaling_available_frequencies
NVPM VERB: MAX_FREQ /sys/devices/system/cpu/cpu5/cpufreq/scaling_max_freq
NVPM VERB: MIN_FREQ /sys/devices/system/cpu/cpu5/cpufreq/scaling_min_freq
NVPM VERB: PARAM TYPE=CLOCK NAME=GPU
NVPM VERB: FREQ_TABLE /sys/devices/platform/17000000.gpu/devfreq_dev/available_frequencies
NVPM VERB: MAX_FREQ /sys/devices/platform/17000000.gpu/devfreq_dev/max_freq
NVPM VERB: MIN_FREQ /sys/devices/platform/17000000.gpu/devfreq_dev/min_freq
NVPM VERB: PARAM TYPE=CLOCK NAME=EMC
NVPM VERB: MAX_FREQ /sys/kernel/nvpmodel_clk_cap/emc
NVPM VERB: 
NVPM VERB: POWER_MODEL: ID=0 NAME=15W
NVPM VERB: CPU_ONLINE CORE_0 1
NVPM VERB: CPU_ONLINE CORE_1 1
NVPM VERB: CPU_ONLINE CORE_2 1
NVPM VERB: CPU_ONLINE CORE_3 1
NVPM VERB: CPU_ONLINE CORE_4 1
NVPM VERB: CPU_ONLINE CORE_5 1
NVPM VERB: FBP_POWER_GATING FBP_PG_MASK 2
NVPM VERB: TPC_POWER_GATING TPC_PG_MASK 240
NVPM VERB: GPU_POWER_CONTROL_ENABLE GPU_PWR_CNTL_EN on
NVPM VERB: CPU_A78_0 MIN_FREQ 729600
NVPM VERB: CPU_A78_0 MAX_FREQ 1497600
NVPM VERB: CPU_A78_1 MIN_FREQ 729600
NVPM VERB: CPU_A78_1 MAX_FREQ 1497600
NVPM VERB: CPU_A78_2 MIN_FREQ 729600
NVPM VERB: CPU_A78_2 MAX_FREQ 1497600
NVPM VERB: CPU_A78_3 MIN_FREQ 729600
NVPM VERB: CPU_A78_3 MAX_FREQ 1497600
NVPM VERB: CPU_A78_4 MIN_FREQ 729600
NVPM VERB: CPU_A78_4 MAX_FREQ 1497600
NVPM VERB: CPU_A78_5 MIN_FREQ 729600
NVPM VERB: CPU_A78_5 MAX_FREQ 1497600
NVPM VERB: GPU MIN_FREQ 0
NVPM VERB: GPU MAX_FREQ 612000000
NVPM VERB: GPU_POWER_CONTROL_DISABLE GPU_PWR_CNTL_DIS auto
NVPM VERB: EMC MAX_FREQ 2133000000
NVPM VERB: 
NVPM VERB: POWER_MODEL: ID=1 NAME=25W
NVPM VERB: CPU_ONLINE CORE_0 1
NVPM VERB: CPU_ONLINE CORE_1 1
NVPM VERB: CPU_ONLINE CORE_2 1
NVPM VERB: CPU_ONLINE CORE_3 1
NVPM VERB: CPU_ONLINE CORE_4 1
NVPM VERB: CPU_ONLINE CORE_5 1
NVPM VERB: FBP_POWER_GATING FBP_PG_MASK 2
NVPM VERB: TPC_POWER_GATING TPC_PG_MASK 240
NVPM VERB: GPU_POWER_CONTROL_ENABLE GPU_PWR_CNTL_EN on
NVPM VERB: CPU_A78_0 MIN_FREQ 729600
NVPM VERB: CPU_A78_0 MAX_FREQ 1344000
NVPM VERB: CPU_A78_1 MIN_FREQ 729600
NVPM VERB: CPU_A78_1 MAX_FREQ 1344000
NVPM VERB: CPU_A78_2 MIN_FREQ 729600
NVPM VERB: CPU_A78_2 MAX_FREQ 1344000
NVPM VERB: CPU_A78_3 MIN_FREQ 729600
NVPM VERB: CPU_A78_3 MAX_FREQ 1344000
NVPM VERB: CPU_A78_4 MIN_FREQ 729600
NVPM VERB: CPU_A78_4 MAX_FREQ 1344000
NVPM VERB: CPU_A78_5 MIN_FREQ 729600
NVPM VERB: CPU_A78_5 MAX_FREQ 1344000
NVPM VERB: GPU MIN_FREQ 0
NVPM VERB: GPU MAX_FREQ 918000000
NVPM VERB: GPU_POWER_CONTROL_DISABLE GPU_PWR_CNTL_DIS auto
NVPM VERB: EMC MAX_FREQ 3199000000
NVPM VERB: 
NVPM VERB: POWER_MODEL: ID=2 NAME=MAXN_SUPER
NVPM VERB: CPU_ONLINE CORE_0 1
NVPM VERB: CPU_ONLINE CORE_1 1
NVPM VERB: CPU_ONLINE CORE_2 1
NVPM VERB: CPU_ONLINE CORE_3 1
NVPM VERB: CPU_ONLINE CORE_4 1
NVPM VERB: CPU_ONLINE CORE_5 1
NVPM VERB: FBP_POWER_GATING FBP_PG_MASK 2
NVPM VERB: TPC_POWER_GATING TPC_PG_MASK 240
NVPM VERB: GPU_POWER_CONTROL_ENABLE GPU_PWR_CNTL_EN on
NVPM VERB: CPU_A78_0 MIN_FREQ 729600
NVPM VERB: CPU_A78_0 MAX_FREQ 9223372036854775807
NVPM VERB: CPU_A78_1 MIN_FREQ 729600
NVPM VERB: CPU_A78_1 MAX_FREQ 9223372036854775807
NVPM VERB: CPU_A78_2 MIN_FREQ 729600
NVPM VERB: CPU_A78_2 MAX_FREQ 9223372036854775807
NVPM VERB: CPU_A78_3 MIN_FREQ 729600
NVPM VERB: CPU_A78_3 MAX_FREQ 9223372036854775807
NVPM VERB: CPU_A78_4 MIN_FREQ 729600
NVPM VERB: CPU_A78_4 MAX_FREQ 9223372036854775807
NVPM VERB: CPU_A78_5 MIN_FREQ 729600
NVPM VERB: CPU_A78_5 MAX_FREQ 9223372036854775807
NVPM VERB: GPU MIN_FREQ 0
NVPM VERB: GPU MAX_FREQ 9223372036854775807
NVPM VERB: GPU_POWER_CONTROL_DISABLE GPU_PWR_CNTL_DIS auto
NVPM VERB: EMC MAX_FREQ 9223372036854775807
NVPM VERB: 
NVPM VERB: POWER_MODEL: ID=3 NAME=7W
NVPM VERB: CPU_ONLINE CORE_0 1
NVPM VERB: CPU_ONLINE CORE_1 1
NVPM VERB: CPU_ONLINE CORE_2 1
NVPM VERB: CPU_ONLINE CORE_3 1
NVPM VERB: CPU_ONLINE CORE_4 0
NVPM VERB: CPU_ONLINE CORE_5 0
NVPM VERB: FBP_POWER_GATING FBP_PG_MASK 2
NVPM VERB: TPC_POWER_GATING TPC_PG_MASK 252
NVPM VERB: GPU_POWER_CONTROL_ENABLE GPU_PWR_CNTL_EN on
NVPM VERB: CPU_A78_0 MIN_FREQ 729600
NVPM VERB: CPU_A78_0 MAX_FREQ 960000
NVPM VERB: GPU MIN_FREQ 0
NVPM VERB: GPU MAX_FREQ 408000000
NVPM VERB: GPU_POWER_CONTROL_DISABLE GPU_PWR_CNTL_DIS auto
NVPM VERB: EMC MAX_FREQ 2133000000
NVPM VERB:
```
#colbreak()

= Hardware Thermal Configurations <app:thermal-zones>

Raw configuration output from the Jetson Linux `sysfs` thermal zones, detailing
the hardware trip points for active cooling, software thermal throttling (DVFS),
and critical hardware shutdowns. Temperatures are represented in millidegrees
Celsius.

```text
tim@jetson:~$ grep "" /sys/class/thermal/thermal_zone*/type
/sys/class/thermal/thermal_zone0/type:cpu-thermal
/sys/class/thermal/thermal_zone1/type:gpu-thermal
/sys/class/thermal/thermal_zone2/type:cv0-thermal
/sys/class/thermal/thermal_zone3/type:cv1-thermal
/sys/class/thermal/thermal_zone4/type:cv2-thermal
/sys/class/thermal/thermal_zone5/type:soc0-thermal
/sys/class/thermal/thermal_zone6/type:soc1-thermal
/sys/class/thermal/thermal_zone7/type:soc2-thermal
/sys/class/thermal/thermal_zone8/type:tj-thermal

tim@jetson:~$ grep "" /sys/class/thermal/thermal_zone*/trip_point*_temp
/sys/class/thermal/thermal_zone0/trip_point_0_temp:99000
/sys/class/thermal/thermal_zone0/trip_point_1_temp:104500
/sys/class/thermal/thermal_zone0/trip_point_2_temp:70000
/sys/class/thermal/thermal_zone1/trip_point_0_temp:99000
/sys/class/thermal/thermal_zone1/trip_point_1_temp:104500
/sys/class/thermal/thermal_zone1/trip_point_2_temp:70000
/sys/class/thermal/thermal_zone8/trip_point_0_temp:35000
/sys/class/thermal/thermal_zone8/trip_point_1_temp:74000
/sys/class/thermal/thermal_zone8/trip_point_2_temp:95000
/sys/class/thermal/thermal_zone8/trip_point_3_temp:104500
```
]
#colbreak()
#columns(2, gutter: 16pt)[
#set par(justify: false)
#bibliography("refs.bib", title: "References", style: "ieee")
]
]
