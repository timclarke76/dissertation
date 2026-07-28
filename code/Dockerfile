FROM nvcr.io/nvidia/l4t-jetpack:r36.4.0

RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    wget \
    git \
    cmake \
    pkg-config \
    libssl-dev \
    python3-pip \
    python3-venv \
    && add-apt-repository ppa:ubuntu-toolchain-r/test -y \
    && apt-get update \
    && apt-get install -y gcc-15 g++-15 \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-15 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-15 100 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 100 \
    && rm -rf /var/lib/apt/lists/*

ARG POETRY_VERSION="2.1.1"
RUN pip3 install --no-cache-dir "poetry==${POETRY_VERSION}"

ARG RUST_VERSION="1.97.1"
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --default-toolchain ${RUST_VERSION}

WORKDIR /app

# Pre-build the Rust dependencies to avoid re-downloading them on every build.
RUN mkdir -p generator/src pipeline-rust/src \
    && echo "fn main() {}" > generator/src/main.rs \
    && echo "fn main() {}" > pipeline-rust/src/main.rs
COPY generator/Cargo.toml generator/Cargo.lock ./generator/
RUN cd generator && cargo build --release
COPY pipeline-rust/Cargo.toml pipeline-rust/Cargo.lock ./pipeline-rust/
RUN cd pipeline-rust && cargo build --release

COPY . /app

# Adds a pre-downloaded ONNX wheel for Python, avoiding the need to download
# from an unreliable remote host during the build process. Creates symbolic
# links to the shared library file to satisfy C++ and Rust dependencies.
RUN cd /app/pipeline-py \
    && poetry config virtualenvs.in-project true \
    && poetry install --no-root \
    && poetry add /app/pipeline-py/vendor/onnxruntime_gpu-1.24.0-cp310-cp310-linux_aarch64.whl \
    && cd .venv/lib/python3.10/site-packages/onnxruntime/capi/ \
    && ln -s libonnxruntime.so.1.24.0 libonnxruntime.so.1 \
    && ln -s libonnxruntime.so.1.24.0 libonnxruntime.so

RUN cd /app/pipeline-cpp \
    && cmake . \
    && cmake --build . --parallel 6

RUN cd /app/generator \
    && find src -type f -name "*.rs" -exec touch {} + \
    && cargo build --release

RUN cd /app/pipeline-rust \
    && find src -type f -name "*.rs" -exec touch {} + \
    && cargo build --release

CMD ["/bin/bash"]
