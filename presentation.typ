#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import fletcher.shapes: circle, cylinder, diamond, pill, rect
#import "@preview/touying:0.7.3": *
#import themes.metropolis: *

#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  footer-right: none,
  config-colors(
    neutral-lightest: rgb("#FFFFFF"),
  ),
  config-info(
    title: [A Comparative Analysis of Memory Management, Concurrency, and
    Performance in Edge-AI],
    author: [Timothy Clarke],
    institution: [University of Dundee],
  ),
)

#set text(
  font: "Libertinus Serif",
  size: 17pt,
  kerning: true,
  ligatures: true,
)

#set list(spacing: 1.0em)

#show heading: set block(below: 1em)

#let red = rgb("F8D7DA")
#let pure_red = rgb(255, 0, 0)
#let dark_red = rgb("#E56C76")
#let light_red = rgb("#fce7f3")
#let dark_blue = rgb("0066cc")
#let blue = rgb("CCE5FF")
#let light_blue = rgb("#DBEDFF")
#let pale_blue = rgb("#EBF4FF")
#let green = rgb("D4EDDA")
#let pure_green = rgb(22, 163, 74)
#let pale_green = rgb("#EDF8EF")
#let cream = rgb("FFFBEB")
#let pale_cream = rgb("#FFFEF9")
#let grey = luma(150)
#let dark_grey = luma(90)
#let light_grey = luma(250)
#let charcoal = rgb("#2D3748")


#title-slide[]

== Cloud vs Edge AI

#figure[
  #set text(size: 11pt)

  #let n(p, t) = node(p, [#t])
  #let e(p1, p2, t) = edge(p1, p2, "-|>", label: align(center)[#t])
  #let t(p, t) = node(p, stroke: none, fill: none,
    text(weight: "bold", size: 14pt, fill: dark_grey)[#t])
  #let nn(p, t) = node(p, stroke: none, fill: none, text(fill: pure_red)[#t])
  #let ne(p1, p2) = edge(p1, p2, "--|>", stroke: 0.5pt + pure_red)

  #diagram(
    spacing: (80pt, 60pt),
    node-stroke: 1pt + grey,
    node-fill: pale_blue,
    node-corner-radius: 5pt,
    edge-stroke: 1pt + rgb("555555"),
    mark-scale: 1.2,

    t((0, 1 ), [Cloud-AI\ Remote Inference]),
    n((1, 1), [*Sensors*\ (Camera, IMU)]),
    e((1, 1), (2, 1), [Raw Data]),
    n((2, 1), [*Generic Device*\ e.g. mobile phone]),
    edge((2, 1), (3, 1), "<|--|>", label: align(center)[Internet]),
    nn((2.30, 0), [_Interception_]),
    ne((2.30, 0), (2.45, 0.8)),
    nn((2.6, 0.30), [_Increased\ Latency_]),
    ne((2.6, 0.30), (2.50, 0.8)),
    n((3, 1), [*Cloud Server*\ (Remote Inference)]),
    nn((2.9, 0), [_Data\ Breaches_]),
    ne((2.9, 0), (3, 0.8)),
    nn((3.30, 0.25), [_Mishandling\ of Data_]),
    ne((3.30, 0.25), (3.05, 0.8)),

    t((0, 2), [Edge-AI\ Local Inference]),
    n((1, 2), [*Sensors*\ (Camera, IMU)]),
    e((1, 2), (2, 2), [Raw Data]),
    n((2, 2), [*Edge-AI Device*\ e.g. Jetson Orin Nano]),
    nn((1.50, 2.85), [_Limited Compute_]),
    ne((1.5, 2.85), (1.8, 2.25)),
    nn((2.0, 2.6), [_Power Capping_]),
    ne((2.0, 2.6), (2.0, 2.25)),
    nn((2.3, 2.85), [_Thermal Limits_]),
    ne((2.3, 2.85), (2.2, 2.25)),
  )
]

== Backpressure Policies

#columns(2, gutter: 16pt)[
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
)
#colbreak()
*Flow Control:*
  - *Bounded Queue:* Blocks until space becomes available in the consumer buffer.
  - *Exponential Backoff:* Sleeps for an exponentially increasing time period before retrying to push data
    into the consumer buffer.

#v(2em)

*Load Shedding:*
  - *Drop Oldest:* Drops the oldest data in the consumer buffer to make room for
    new data.
  - *Drop Newest:* Drops incoming data when the buffer is full.
  - *Adaptive Decimation:* Dynamically downsamples the data stream.
]


== The Architecture

#columns(2, gutter: 16pt)[
#figure(
  pad(top: 0em)[
    #set text(size: 6pt)

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
      spacing: (50pt, 23pt),

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
)

#colbreak()

*Data Streams (3):* one exists for each sensor in use. Zero-allocation after
initialisation.

*Bridge Threads (3):* spin-waits on `/dev/shm`, attempts to add ingested frames
into bounded buffer, applying backpressure policy when necessary.

*Inference Threads (3):* pulls frames from the bounded queue to create temporal
windows and execute the ONNX model, pushing the result to the MPSC channel.

*Late-Fusion Thread (1):* consumes from the MPSC channel, anchored to the RGB
stream. Pushes to the telemetry threads.

*Telemetry Threads (3):* uses HDR Histogram to calculate telemetry for later
analysis, utilising a triple-buffered channel for zero-wait on the hot thread.
]

== Baseline Performance (unconstrained MAXN_SUPER)

#figure(
  pad(top: 0em)[
    #image("code/results/img/MAXN_SUPER-baseline-performance.pdf", width: 85%)
  ],
)

== Baseline Performance (constrained 7-Watt)

#figure(
  pad(top: 0em)[
    #image("code/results/img/07-watt-baseline-performance.pdf", width: 85%)
  ],
)

== Backpressure Trade-off

#columns(2, gutter: 16pt)[
#figure(
  pad()[
    #image("code/results/img/MAXN_SUPER-dropped-frames.pdf", width: 74%)
  ],
  supplement: none,
  caption: text(size: 12pt)[#v(-0.5em) `load` = 2.5]
)

#figure(
  pad(top: 0.5em)[
    #image("code/results/img/MAXN_SUPER-latency-comparison.pdf", width: 74%)
  ],
  supplement: none,
  caption: text(size: 12pt)[#v(-0.5em) `load` = 7.0]
)

#colbreak()

*Moderate Load:* Flow-control policies absorb the spikes by utilising the
elasticity of the unbounded buffer, while load-shedding policies drop frames
unnecessarily to maintain latency deadlines.

#v(5.25em)

*Severe Load:* Using flow-control policies, the unbounded buffer fills to
maximum capacity, pushing latency beyond the deadline.
]

== Conclusion

#align(center)[
  #set text(size: 11pt)
  #diagram(
    spacing: (60pt, 40pt),
    node-stroke: 1pt + rgb("555555"),
    node-fill: rgb("f9f9f9"),
    node-corner-radius: 5pt,
    edge-stroke: 1pt + rgb("555555"),
    mark-scale: 1.2,

    node((1.025, 0), [*Edge-AI\ Deployment*]),

    node((0,1), [*Backpressure\ Strategy*]),
    edge((1.025, 0), (1.025, 0.5), (0, 0.5), (0, 1), "-|>"),
    node((-0.75,2), align(center)[*Flow Control*\
      (Exp. Backoff)\ _Data Preservation_]),
    edge((0,1), (0,1.4), (-0.75,1.4), (-0.75,2), "-|>"),
    node((0,2), align(center)[*Load Shedding*\
      (Drop Oldest)\ _Latency Deadlines_]),
    edge((0,1), (0,2), "-|>"),
    node((0.8,2), align(center)[*Dynamic Load Shedding*\
      #text(size: 11pt)[(Adaptive Decimation)]\ 
      _Temporal Continuity_]),
    edge((0,1), (0,1.4), (0.8,1.4), (0.8,2), "-|>"),

    node((2.05,1), [*Language\ Selection*]),
    edge((1.025,0), (1.025,0.5), (2.05,0.5), (2.05,1), "-|>"),
    node((1.7,2), stroke: 1.5pt + rgb("009900"), fill: rgb("e6ffe6"),
      align(center)[*Rust*\ #align(left)[_Performant\ Memory Safety_]]),
    edge((2.05,1), (2.05,1.4), (1.75,1.4), (1.75,2), "-|>"),
    node((2.55,2), stroke: 1.5pt + rgb("cc0000"), fill: rgb("ffe6e6"),
      align(center)[*Python*\ #align(left)[_GIL Thread-Starvation\
      Scalability_]]),
    edge((2.05,1), (2.05,1.4), (2.6,1.4), (2.6, 2), "-|>"),
  )
]

