#!/bin/bash
# run_s12c_sup.sh — the supervisor for s12c_runner.sh (the established pattern:
# a live wsl client held for the runner's whole life; NO timeout on the
# background shell call that runs this script — a timeout killed the first
# v6 supervisor while the setsid'd runner survived).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
setsid nohup bash "$WS/research/s12c_runner.sh" > /home/dmin/qwen36-strata-project/s12c_launch.log 2>&1 < /dev/null &
for i in $(seq 1 400); do
  ps aux --width 250 | grep -q "s12c_runner" || { echo "s12c runner exited after $i polls"; exit 0; }
  sleep 15
done
echo "supervisor timeout (the runner may still be running)"
