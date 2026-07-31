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

# SUPER_MAXN power mode
nvpmodel -m 2

# Maximum performance clocks
jetson_clocks

# Disable automatic fan control
systemctl stop nvfancontrol
IMAGE="dissertation:latest"
ORT_DYLIB_PATH="/app/pipeline-py/.venv/lib/python3.10/site-packages/onnxruntime/capi/libonnxruntime.so.1.24.0"
VOLUME="$(pwd)/results"
rm -rf "$VOLUME"
mkdir -p "$VOLUME"

GEN_CORE="5"
PIPE_CORES="1-4"
GEN_PRIORITY="99"
GEN_LOAD="1.0"
RUNTIME_SECS=3

LOADS=($(seq "1.0" "0.25" "1.5"))
LANGUAGES=("cpp" "rust" "python")

POLICIES=(
    "BoundedQueue"
    "ExponentialBackoff"
    "DropOldest"
    "DropNewest"
    "AdaptiveDecimation"
)

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

DOCKER_ARGS=(
    --ipc=host
    --privileged
    --runtime=nvidia
    --cap-add=SYS_NICE
    --volume $VOLUME:/results
)

TRT_ARGS=(
    ${DOCKER_ARGS[@]}
    --volume $(pwd)/models/:/app/models
    --volume $(pwd)/trt_cache:/app/trt_cache
    --rm
)

GENERATOR_ARGS=(
    ${DOCKER_ARGS[@]}
    --detach
)

PIPELINE_ARGS=(
    ${TRT_ARGS[@]}
    --cpuset-cpus=$PIPE_CORES
)

rm -rf $(pwd)/models/*_epctx.onnx $(pwd)/models/trt_cache/ $(pwd)/trt_cache/
docker run --rm ${TRT_ARGS[@]} -w /app $IMAGE \
    /app/pipeline-py/.venv/bin/python3 compile_trt.py
docker run ${PIPELINE_ARGS[@]} -e ORT_DYLIB_PATH="$ORT_DYLIB_PATH" \
    --workdir "$WORK_DIR" $IMAGE \
    /app/pipeline-rust/target/release/pipeline-rust --precompile
chown -R tim:tim $(pwd)/models/
chown -R tim:tim $(pwd)/trt_cache/

BASE_TEMP=$(get_temp)
echo "Baseline temperature: ${BASE_TEMP}°C"
echo ""

for policy in "${POLICIES[@]}"; do
    for load in "${LOADS[@]}"; do
        for lang in "${LANGUAGES[@]}"; do
            EVAL_DIR="${policy}/load_${load}/${lang}"
            mkdir -p "$VOLUME/$EVAL_DIR"
            WORK_DIR="/results/$EVAL_DIR"
            ln -sfn "/app/models" "$VOLUME/$EVAL_DIR/models"
            ln -sfn "/app/trt_cache" "$VOLUME/$EVAL_DIR/trt_cache"

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

            EVAL="${GRAY}${RESET}${CYAN}Language:${RESET} %-6s ${GRAY}|${RESET} ${YELLOW}Policy:${RESET} %-18s ${GRAY}|${RESET} ${BLUE}Load:${RESET} %-5s${GRAY}${RESET}"
            echo 255 > /sys/class/hwmon/hwmon0/pwm1

            while true; do
                TEMP=$(get_temp)

                if [ "$TEMP" -le "$BASE_TEMP" ]; then
                    printf "\r$(printf "$EVAL" "$lang" "$policy" "$load") ${GRAY}|${RESET} ${BOLD}Temp:${RESET} ${GREEN}%2d°C${RESET}\033[K\n" "$TEMP"
                    break
                fi

                printf "\r$(printf "$EVAL" "$lang" "$policy" "$load") ${GRAY}|${RESET} ${BOLD}Temp:${RESET} ${YELLOW}%2d°C${RESET}\033[K" "$TEMP"
                sleep 2
            done

            echo 0 > /sys/class/hwmon/hwmon0/pwm1

            stdbuf -oL tegrastats --interval 1000 | \
                awk -W interactive '{ print systime(), $0 }' > \
                "$VOLUME/$EVAL_DIR/tegrastats.log" &
            TEGRA_PID=$!
            rm -f /dev/shm/RGB /dev/shm/Accelerometer /dev/shm/Gyroscope

            GEN_CONTAINER_ID=$(docker run ${GENERATOR_ARGS[@]} $IMAGE \
                /app/generator/target/release/generator \
                    --settings /app/generator/settings.toml \
                    --core $GEN_CORE \
                    --priority $GEN_PRIORITY \
                    --load $GEN_LOAD \
                    --runtime-seconds $RUNTIME_SECS \
                    --output $WORK_DIR/generator.json \
                    --headless)

            # Wait for the generator to create the shared memory files before
            # starting the pipeline
            while [ ! -e /dev/shm/RGB ] \
                && [ ! -e /dev/shm/Accelerometer ] \
                && [ ! -e /dev/shm/Gyroscope ]
            do
                sleep 0.5
            done

            if [ "$lang" == "cpp" ]; then
                docker run ${PIPELINE_ARGS[@]} --workdir "$WORK_DIR" $IMAGE \
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
# Change ownership of the results directory to the current user (Docker will
# have created the files as root)
chown -R tim:tim $VOLUME
