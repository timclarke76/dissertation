cmake_minimum_required(VERSION 3.5)
project(pipeline_cpp)

# set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=address -g -fno-omit-frame-pointer")
# set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=address")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)

find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
    set(CMAKE_CXX_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
    set(CMAKE_C_COMPILER_LAUNCHER   ${CCACHE_PROGRAM})
    message(STATUS "ccache enabled successfully!")
endif()

include(FetchContent)
set(CMAKE_WARN_DEPRECATED OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
    argparse
    GIT_REPOSITORY https://github.com/p-ranav/argparse.git
    GIT_TAG        v3.2
)
FetchContent_MakeAvailable(argparse)

FetchContent_Declare(
    tomlplusplus
    GIT_REPOSITORY https://github.com/marzer/tomlplusplus.git
    GIT_TAG        v3.4.0
)
FetchContent_MakeAvailable(tomlplusplus)

FetchContent_Declare(
    moodycamel
    GIT_REPOSITORY https://github.com/cameron314/concurrentqueue.git
    GIT_TAG        v1.0.5
)
FetchContent_MakeAvailable(moodycamel)

FetchContent_Declare(
    hdrhistogram
    GIT_REPOSITORY https://github.com/HdrHistogram/HdrHistogram_c.git
    GIT_TAG        0.11.10
)
FetchContent_MakeAvailable(hdrhistogram)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -Wall -Wextra -Wpedantic -pthread")

add_executable(pipeline_cpp 
    src/config/args.cpp
    src/config/settings.cpp
    src/inference/inference_engine.cpp
    src/os/allocator.cpp
    src/os/shm.cpp 
    src/thread/bridge.cpp
    src/thread/fusion.cpp
    src/thread/inference.cpp
    src/thread/telemetry.cpp
    src/histogram.cpp 
    src/main.cpp 
)

include_directories("${CMAKE_CURRENT_SOURCE_DIR}/src")
include_directories("${CMAKE_CURRENT_SOURCE_DIR}/_deps/moodycamel-src/")
include_directories("${CMAKE_CURRENT_SOURCE_DIR}/_deps/tomlplusplus-src/include/")
include_directories("${CMAKE_CURRENT_SOURCE_DIR}/vendor/onnxruntime/include")

target_link_libraries(pipeline_cpp
    rt
    pthread
    hdr_histogram_static
    argparse
    "${CMAKE_CURRENT_SOURCE_DIR}/../pipeline-py/.venv/lib/python3.10/site-packages/onnxruntime/capi/libonnxruntime.so.1.24.0"
)
