#!/usr/bin/env bash

# Script must be run as root.
if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

RESET="\033[0m"
BOLD="\033[1m"
CYAN="\033[36m"
YELLOW="\033[33m"
GREEN="\033[32m"
BLUE="\033[34m"
GRAY="\033[90m"

# Disable NTP
timedatectl set-ntp false

# sudo nvpmodel -p --verbose | grep POWER_MODEL
# 0: 15 watt
# 1: 25 watt
# 2: MAXN_SUPER
# 3: 7 watt
powermode=$1
nvpmodel -m $powermode

# Set the Jetson clocks to maximum performance if the power mode is set to
# MAXN_SUPER (2). Otherwise, restore the default clocks.
if [ "$powermode" -eq 2 ]; then
    jetson_clocks
else
    jetson_clocks --restore >/dev/null 2>&1 || true
fi

# Disable automatic fan control
systemctl stop nvfancontrol

# Silence kernel console spam to prevent I/O latency jitter
dmesg -n 1

IMAGE="dissertation:latest"
ORT_DYLIB_PATH="/app/pipeline-py/.venv/lib/python3.10/site-packages/onnxruntime/capi/libonnxruntime.so.1.24.0"
VOLUME="$(pwd)/results"
rm -rf "$VOLUME"
mkdir -p "$VOLUME"

TARGET_TEMP=60
GEN_PRIORITY="99"
RUNTIME_SECS="600"

if [ "$powermode" -eq 2 ]; then
    GEN_CORE="5"
    PIPE_CORES="1-4"
else
    GEN_CORE="3"
    PIPE_CORES="1-2"
fi

python_loads=($(seq 0.01 0.01 0.07) 1.00 5.5)
compiled_loads=(0.04 0.05 $(seq 1.0 0.25 2.5) $(seq 4.0 1.5 10.0) $(seq 12.5 2.5 20.0))
declare -A LANGUAGES=(
    ["python"]="python_loads"
    ["cpp"]="compiled_loads"
    ["rust"]="compiled_loads"
)

POLICIES=(
    "BoundedQueue"
    "ExponentialBackoff"
    "DropOldest"
    "DropNewest"
    "AdaptiveDecimation"
)

# Get the maximum temperature of the Jetson in degrees Celsius.
get_temp() {
    local max_temp=0

    for tz in /sys/class/thermal/thermal_zone*/temp; do
        local temp

        temp=$(cat "$tz" 2>/dev/null) || continue

        if [ "$temp" -gt "$max_temp" ]; then
            max_temp=$temp
        fi
    done

    echo $((max_temp / 1000))
}

EVAL="${GRAY}${RESET}${CYAN}Language:${RESET} %-6s ${GRAY}|${RESET} ${YELLOW}Policy:${RESET} %-18s ${GRAY}|${RESET} ${BLUE}Load:${RESET} %-5s${GRAY}${RESET}"

# Warm up the Jetson to the target temperature by running a CPU-intensive
# workload.
warm_up() {
    local target_temp=$1
    local curr_temp=$(get_temp)

    if [ "$curr_temp" -ge "$target_temp" ]; then
        return
    fi

    echo 0 > /sys/class/hwmon/hwmon0/pwm1

    while true; do
        curr_temp=$(get_temp)

        if [ "$curr_temp" -ge "$target_temp" ]; then
            break
        fi

        printf "\r$(printf "$EVAL" "$lang" "$policy" "$load") ${GRAY}|${RESET} ${BOLD}Warming up:${RESET} ${YELLOW}%2d°C / %2d°C${RESET}\033[K" "$curr_temp" "$target_temp"

        cat /dev/urandom > /dev/null & 
        URANDOM_PID=$!
        sleep 2
        kill $URANDOM_PID 2>/dev/null
    done
}

# Cool down the Jetson to the target temperature by running the fan at full
# speed.
cool_down() {
    local target_temp=$1
    local curr_temp=$(get_temp)

    if [ "$curr_temp" -le "$target_temp" ]; then
        return
    fi

    echo 255 > /sys/class/hwmon/hwmon0/pwm1

    while true; do
        curr_temp=$(get_temp)

        if [ "$curr_temp" -le "$target_temp" ]; then
            break
        fi

        printf "\r$(printf "$EVAL" "$lang" "$policy" "$load") ${GRAY}|${RESET} ${BOLD}Cooling down:${RESET} ${YELLOW}%2d°C / %2d°C${RESET}\033[K" "$curr_temp" "$target_temp"

        sleep 2
    done
}

# Balance the temperature of the Jetson by warming it up or cooling it down to
# the target temperature.
balance_temperature() {
    while true; do
        curr_temp=$(get_temp)

        if [ "$curr_temp" -eq "$TARGET_TEMP" ]; then
            break
        elif [ "$curr_temp" -lt "$TARGET_TEMP" ]; then
            warm_up $TARGET_TEMP
        elif [ "$curr_temp" -gt "$TARGET_TEMP" ]; then
            cool_down $TARGET_TEMP
        fi
    done

    echo 0 > /sys/class/hwmon/hwmon0/pwm1
    printf "\r$(printf "$EVAL" "$lang" "$policy" "$load") ${GRAY}|${RESET} ${BOLD}Temp:${RESET} ${GREEN}%2d°C${RESET}\033[K\n" "$curr_temp"
}

# The following Docker arguments are used for all containers. They set the IPC
# mode to host, enable privileged mode, use the NVIDIA runtime, add the SYS_NICE
# capability, and mount the results volume.
DOCKER_ARGS=(
    --ipc=host
    --privileged
    --runtime=nvidia
    --cap-add=SYS_NICE
    --volume $VOLUME:/results
)

# The following Docker arguments are used for the TensorRT compilation
# container. They mount the models and TensorRT cache directories, and remove
# the container after it exits.
TRT_ARGS=(
    ${DOCKER_ARGS[@]}
    --volume $(pwd)/models/:/app/models
    --volume $(pwd)/trt_cache:/app/trt_cache
    --rm
)

# The following Docker arguments are used for the generator container, in
# addition to the common Docker arguments. They run the container in detached
# mode.
GENERATOR_ARGS=(
    ${DOCKER_ARGS[@]}
    --detach
)

# The following Docker arguments are used for the pipeline containers, in
# addition to the common Docker arguments. They set the CPU affinity for the
# pipeline container to the specified cores.
PIPELINE_ARGS=(
    ${TRT_ARGS[@]}
    --cpuset-cpus=$PIPE_CORES
)

# Compile the TensorRT models and precompile the ONNX models for the C++ and
# Rust pipelines. This is done to avoid the overhead of compiling the models
# during the evaluation runs.
rm -rf $(pwd)/models/*_epctx.onnx $(pwd)/models/trt_cache/ $(pwd)/trt_cache/
docker run --rm ${TRT_ARGS[@]} -w /app $IMAGE \
    /app/pipeline-py/.venv/bin/python3 compile_trt.py
docker run ${PIPELINE_ARGS[@]} -e ORT_DYLIB_PATH="$ORT_DYLIB_PATH" \
    --workdir "$WORK_DIR" $IMAGE \
    /app/pipeline-rust/target/release/pipeline-rust --precompile
chown -R tim:tim $(pwd)/models/
chown -R tim:tim $(pwd)/trt_cache/

for lang in "${!LANGUAGES[@]}"; do
    declare -n LOADS="${LANGUAGES[$lang]}"

    for policy in "${POLICIES[@]}"; do
        for load in "${LOADS[@]}"; do
            EVAL_DIR="${lang}/${policy}/${load}"
            mkdir -p "$VOLUME/$EVAL_DIR"
            WORK_DIR="/results/$EVAL_DIR"
            ln -sfn "/app/models" "$VOLUME/$EVAL_DIR/models"
            ln -sfn "/app/trt_cache" "$VOLUME/$EVAL_DIR/trt_cache"
            rm -f /dev/shm/RGB /dev/shm/Accelerometer /dev/shm/Gyroscope

            cat <<EOF > "$VOLUME/settings.toml"
[rgb_queue_config]
name = "RGB"
fps = 30
capacity_frames = 3
frame_shape = [1, 3, 1080, 1920]
item_size_bytes = 1

[accel_queue_config]
name = "Accelerometer"
fps = 1600
capacity_frames = 160
frame_shape = [1, 53, 3]
item_size_bytes = 4

[gyro_queue_config]
name = "Gyroscope"
fps = 2000
capacity_frames = 200
frame_shape = [1, 66, 3]
item_size_bytes = 4

EOF

            if [ "$policy" == "AdaptiveDecimation" ]; then
                cat <<EOF >> "$VOLUME/settings.toml"
[rgb_policy]
type = "AdaptiveDecimation"
threshold = 2
min_ratio = 2
max_ratio = 10

[accel_policy]
type = "AdaptiveDecimation"
threshold = 128 # 80% of capacity_frames
min_ratio = 2
max_ratio = 10

[gyro_policy]
type = "AdaptiveDecimation"
threshold = 160 # 80% of capacity_frames
min_ratio = 2
max_ratio = 10
EOF
            elif [ "$policy" == "ExponentialBackoff" ]; then
                cat <<EOF >> "$VOLUME/settings.toml"
[rgb_policy]
type = "ExponentialBackoff"
base_nanos = 1_000_000
max_nanos = 33_300_000
multiplier = 2.0

[accel_policy]
type = "ExponentialBackoff"
base_nanos = 1_000_000
max_nanos = 33_300_000
multiplier = 2.0

[gyro_policy]
type = "ExponentialBackoff"
base_nanos = 1_000_000
max_nanos = 33_300_000
multiplier = 2.0
EOF
            else
                cat <<EOF >> "$VOLUME/settings.toml"
[rgb_policy]
type = "${policy}"

[accel_policy]
type = "${policy}"

[gyro_policy]
type = "${policy}"
EOF
            fi

            balance_temperature

            # Start tegrastats in the background and log its output to a file in
            # the results directory. The output is prefixed with the current
            # system time in seconds since the epoch to make it easier to
            # correlate with the telemetry from the pipeline.
            stdbuf -oL tegrastats --interval 1000 | \
                awk -W interactive '{ print systime(), $0 }' > \
                "$VOLUME/$EVAL_DIR/tegrastats.log" &
            TEGRA_PID=$!

            GEN_CONTAINER_ID=$(docker run ${GENERATOR_ARGS[@]} $IMAGE \
                /app/generator/target/release/generator \
                    --settings /app/generator/settings.toml \
                    --core $GEN_CORE \
                    --priority $GEN_PRIORITY \
                    --load $load \
                    --runtime-seconds $RUNTIME_SECS \
                    --output $WORK_DIR/generator.json \
                    --headless)

            # Wait for the generator to create the shared memory files before
            # starting the pipeline
            while [ ! -e /dev/shm/RGB ] \
                || [ ! -e /dev/shm/Accelerometer ] \
                || [ ! -e /dev/shm/Gyroscope ]
            do
                sleep 0.5
            done

            if [ "$lang" == "cpp" ]; then
                docker run ${PIPELINE_ARGS[@]} \
                    --workdir "$WORK_DIR" $IMAGE \
                    /app/pipeline-cpp/pipeline_cpp \
                        --settings /results/settings.toml
            elif [ "$lang" == "rust" ]; then
                docker run ${PIPELINE_ARGS[@]} \
                    -e ORT_DYLIB_PATH="$ORT_DYLIB_PATH" \
                    --workdir "$WORK_DIR" $IMAGE \
                    /app/pipeline-rust/target/release/pipeline-rust \
                        --settings /results/settings.toml

            elif [ "$lang" == "python" ]; then
                docker run ${PIPELINE_ARGS[@]} --workdir "$WORK_DIR" $IMAGE \
                    /app/pipeline-py/.venv/bin/python3 \
                        /app/pipeline-py/pipeline.py \
                            --settings /results/settings.toml
            fi

            docker wait $GEN_CONTAINER_ID > /dev/null
            docker rm $GEN_CONTAINER_ID > /dev/null
            kill $TEGRA_PID 2>/dev/null

            # Cleanup the temporary symlinks to avoid cluttering the results
            # directory
            rm -f "$VOLUME/$EVAL_DIR/models"
            rm -f "$VOLUME/$EVAL_DIR/trt_cache"
        done
    done
done

# Enable NTP
timedatectl set-ntp true

# Restore Jetson clocks to default
jetson_clocks --restore >/dev/null 2>&1 || true

# Restore automatic fan control
systemctl start nvfancontrol

# Restore default kernel console logging
dmesg -n 7

# Change ownership of the results directory to the current user (Docker will
# have created the files as root)
chown -R tim:tim $VOLUME
