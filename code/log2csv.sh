#!/usr/bin/env bash

find $1 -name "tegrastats.log" -exec sh -c '
  awk '\''BEGIN { print "timestamp,cpu_temp,gpu_freq" }
  {
    timestamp = $1;
    temp = ""; gpu = "";

    for(i=2; i<=NF; i++) {
      # Extract GPU frequency (e.g. "GR3D_FREQ 0%@[1014]")
      if ($i == "GR3D_FREQ") {
        split($(i+1), arr, "@");
        gpu = arr[2];
        gsub(/\[|\]/, "", gpu); # Removes both [ and ]
      }

      # Extract CPU/Thermal temperature (e.g. tj@59.843C)
      if ($i ~ /^tj@/) {
        split($i, arr, "@");
        temp = arr[2];
        gsub(/C/, "", temp); # Strip the "C"
      }
    }

    if (temp != "" && gpu != "") print timestamp "," temp "," gpu;
  }'\'' "$1" > "$(dirname "$1")/tegrastats.csv"
' _ {} \;
