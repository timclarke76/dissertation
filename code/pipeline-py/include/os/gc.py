import gc
import sys
import time

pause_ns = 0
_state = {"start_time": 0}


def gc_callback(phase, info):
    """Callback function to track the time spent in garbage collection."""

    global pause_ns

    if phase == "start":
        _state["start_time"] = time.perf_counter_ns()
    elif phase == "stop":
        pause_ns += time.perf_counter_ns() - _state["start_time"]


gc.callbacks.append(gc_callback)
