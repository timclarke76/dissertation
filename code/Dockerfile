FROM nvcr.io/nvidia/l4t-jetpack:r36.4.0

# Prevent interactive prompts during apt installations
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    wget \
    git \
    cmake \
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
COPY . /app

RUN cd /app/generator \
    && cargo build --release

RUN cd /app/pipeline-cpp \
    && cmake . \
    && cmake --build . --parallel 6

RUN cd /app/pipeline-rust \
    && cargo build --release

RUN cd /app/pipeline-py \
    && poetry config virtualenvs.in-project true \
    && poetry install --no-root

CMD ["/bin/bash"]
