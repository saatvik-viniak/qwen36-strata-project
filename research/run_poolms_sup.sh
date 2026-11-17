#!/bin/bash
# run_poolms_sup.sh — the supervisor for poolms_runner.sh (the established
# pattern: a live wsl client held for the runner's whole life; NO timeout on
# the background shell call that runs this script).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
setsid nohup bash "$WS/research/poolms_runner.sh" > /home/dmin/qwen36-strata-project/poolms_sup.log 2>&1 < /dev/null &
for i in $(seq 1 480); do
  ps aux --width 250 | grep -q "poolms_runner" || { echo "poolms runner exited after $i polls"; exit 0; }
  sleep 15
done
echo "supervisor timeout (the runner may still be running)"
