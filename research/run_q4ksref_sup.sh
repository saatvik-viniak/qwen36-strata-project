#!/bin/bash
# run_q4ksref_sup.sh — supervisor for q4ks_ref_bench.sh (the run_prom_sup.sh pattern:
# the background shell job holds the wsl client alive; do NOT pass a timeout to the
# background call that runs this supervisor).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
setsid nohup bash "$WS/research/q4ks_ref_bench.sh" > /home/dmin/qwen36-strata-project/q4ks_ref_launch.log 2>&1 < /dev/null &
for i in $(seq 1 120); do
  ps aux --width 250 | grep -q "q4ks_ref_bench" || { echo "q4ks ref bench exited after $i polls"; exit 0; }
  sleep 15
done
echo "supervisor timeout (the bench may still be running)"
