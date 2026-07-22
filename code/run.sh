#!/bin/bash
set -e

# Disable NTP
timedatectl set-ntp false

# SUPER_MAXN power mode
nvpmodel -m 2

# Maximum performance clocks
jetson_clocks

IMAGE="dissertation:latest"
VOLUME="$(pwd)/results"

GEN_CORE="5"
PIPE_CORES="1-4"
GEN_PRIORITY="99"
GEN_LOAD="1.0"
RUNTIME_SECS=3

LOADS=($(seq "1.0" "0.25" "1.5"))
LANGUAGES=("cpp" "rust" "py")

POLICIES=(
    "DropOldest"
    "DropNewest"
    "BoundedQueue"
    "AdaptiveDecimation"
    "ExponentialBackoff"
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

GENERATOR_ARGS=(
    ${DOCKER_ARGS[@]}
    --detach
)

PIPELINE_ARGS=(
    ${DOCKER_ARGS[@]}
    --cpuset-cpus=$PIPE_CORES
    --rm
)

echo "Settling Jetson."
sleep 10 

BASE_TEMP=$(get_temp)
echo "Baseline temperature: ${BASE_TEMP}°C"

for policy in "${POLICIES[@]}"; do
    for load in "${LOADS[@]}"; do
        for lang in "${LANGUAGES[@]}"; do
            EVAL_DIR="${policy}/load_${load}/${lang}"
            mkdir -p "$VOLUME/$EVAL_DIR"
            WORK_DIR="/results/$EVAL_DIR"

            cat <<EOF > "$VOLUME/settings.toml"
[rgb_queue_config]
name = "RGB"
fps = 30
capacity_frames = 3

[accel_queue_config]
name = "Accelerometer"
fps = 1600
capacity_frames = 160

[gyro_queue_config]
name = "Gyroscope"
fps = 2000
capacity_frames = 200

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
base_nanos = 1
max_nanos = 33.3
multiplier = 2

[accel_policy]
type = "ExponentialBackoff"
base_nanos = 1
max_nanos = 33.3
multiplier = 2

[gyro_policy]
type = "ExponentialBackoff"
base_nanos = 1
max_nanos = 33.3
multiplier = 2
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

            EVAL="Evaluating: Language=$lang | Policy=$policy | Load=$load"

            while true; do
                TEMP=$(get_temp)

                if [ "$TEMP" -le "$BASE_TEMP" ]; then
                    echo -e "\r${EVAL} | Temp: ${TEMP}°C"
                    break
                fi

                echo -ne "\r${EVAL} | Temp: ${TEMP}°C"
                sleep 2
            done

            stdbuf -oL tegrastats --interval 1000 | \
                awk -W interactive '{ print systime(), $0 }' > \
                "$VOLUME/$EVAL_DIR/tegrastats.log" &
            TEGRA_PID=$!

            GEN_CONTAINER_ID=$(docker run ${GENERATOR_ARGS[@]} $IMAGE \
                /app/generator/target/release/generator \
                    --settings /app/generator/settings.toml \
                    --core $GEN_CORE \
                    --priority $GEN_PRIORITY \
                    --load $GEN_LOAD \
                    --runtime-seconds $RUNTIME_SECS \
                    --output $WORK_DIR/generator.json \
                    --headless true)

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
                docker run ${PIPELINE_ARGS[@]} --workdir "$WORK_DIR" $IMAGE \
                    /app/pipeline-rust/target/release/pipeline-rust \
                        --settings /results/settings.toml

            elif [ "$lang" == "py" ]; then
                docker run ${PIPELINE_ARGS[@]} --workdir "$WORK_DIR" $IMAGE \
                    /app/pipeline-py/.venv/bin/python3 \
                        /app/pipeline-py/pipeline.py \
                            --settings /results/settings.toml
            fi

            docker wait $GEN_CONTAINER_ID > /dev/null
            docker rm $GEN_CONTAINER_ID > /dev/null
            kill $TEGRA_PID 2>/dev/null
        done
    done
done

# Enable NTP
timedatectl set-ntp true

# Restore Jetson clocks to default
jetson_clocks --restore 2>/dev/null || true

# Change ownership of the results directory to the current user (Docker will
# have created the files as root)
chown -R $USER:$USER $VOLUME
