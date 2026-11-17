#!/bin/bash
# run_q4ksbase_sup.sh — supervisor for q4ks_baseline_pass.sh (the run_prom_sup.sh
# pattern: the background shell job holds the wsl client alive; the launcher must
# NOT pass a timeout to the background call that runs this supervisor).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
setsid nohup bash "$WS/research/q4ks_baseline_pass.sh" > /home/dmin/qwen36-strata-project/q4ks_base_launch.log 2>&1 < /dev/null &
for i in $(seq 1 300); do
  ps aux --width 250 | grep -q "q4ks_baseline_pass" || { echo "q4ks baseline pass exited after $i polls"; exit 0; }
  sleep 15
done
echo "supervisor timeout (the pass may still be running)"
