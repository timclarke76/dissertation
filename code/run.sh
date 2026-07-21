#!/bin/bash
set -e

IMAGE="dissertation:latest"

GEN_CORE="5"
PIPE_CORES="1-4"
GEN_PRIORITY="99"
GEN_LOAD="1.0"

RUNTIME_SECS=3

VOLUME="$(pwd)/results"
mkdir -p $VOLUME

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

echo "Letting the Jetson settle."
sleep 10 

BASE_TEMP=$(get_temp)
echo "Baseline temperature: ${BASE_TEMP}°C"

for lang in "cpp" "rust" "py"; do
    echo "Evaluating $lang"

    while true; do
        CURR_TEMP=$(get_temp)

        if [ "$CURR_TEMP" -le "$BASE_TEMP" ]; then
            echo -e "\rCurrent temperature: ${CURR_TEMP}°C   "
            break
        fi

        echo -ne "\rCurrent temperature: ${CURR_TEMP}°C   "
        sleep 2
    done

    mkdir -p $VOLUME/$lang

    GEN_CONTAINER_ID=$(docker run ${GENERATOR_ARGS[@]} $IMAGE \
        /app/generator/target/release/generator \
            --settings /app/generator/settings.toml \
            --core $GEN_CORE \
            --priority $GEN_PRIORITY \
            --load $GEN_LOAD \
            --runtime-seconds $RUNTIME_SECS \
            --output /results/generator_${lang}.json \
            --headless true)

    # Wait for the generator to create the shared memory files before starting
    # the pipeline
    while [ ! -e /dev/shm/RGB ] \
        && [ ! -e /dev/shm/Accelerometer ] \
        && [ ! -e /dev/shm/Gyroscope ]
    do
        sleep 0.5
    done

    if [ "$lang" == "cpp" ]; then
        docker run ${PIPELINE_ARGS[@]} --workdir /results/$lang $IMAGE \
            /app/pipeline-cpp/pipeline_cpp \
                --settings /app/pipeline-cpp/settings.toml

    elif [ "$lang" == "rust" ]; then
        docker run ${PIPELINE_ARGS[@]} --workdir /results/$lang $IMAGE \
            /app/pipeline-rust/target/release/pipeline-rust \
                --settings /app/pipeline-rust/settings.toml

    elif [ "$lang" == "py" ]; then
        docker run ${PIPELINE_ARGS[@]} --workdir /results/$lang $IMAGE \
            /app/pipeline-py/.venv/bin/python3 /app/pipeline-py/pipeline.py \
                --settings /app/pipeline-py/settings.toml
    fi

    docker wait $GEN_CONTAINER_ID > /dev/null
    docker rm $GEN_CONTAINER_ID > /dev/null
done
