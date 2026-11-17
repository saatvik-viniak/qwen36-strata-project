#!/bin/bash
# run_q4kspass2_sup.sh — the supervisor for q4ks_pass2_bench.sh (the established
# pattern: a live wsl client held for the runner's whole life; NO timeout on the
# background shell call that runs this script).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
setsid nohup bash "$WS/research/q4ks_pass2_bench.sh" > /home/dmin/qwen36-strata-project/pass2_sup.log 2>&1 < /dev/null &
for i in $(seq 1 480); do
  ps aux --width 250 | grep -q "q4ks_pass2_bench" || { echo "pass2 runner exited after $i polls"; exit 0; }
  sleep 15
done
echo "supervisor timeout (the runner may still be running)"
