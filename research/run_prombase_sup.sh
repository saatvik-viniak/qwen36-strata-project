#!/bin/bash
# run_prombase_sup.sh — the supervisor for promotion_base_pass.sh (the run_v6_sup.sh
# pattern: the background shell job holds the wsl client alive; NO timeout on the
# background call — a 30 s timeout killed the first v6 supervisor).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
setsid nohup bash "$WS/research/promotion_base_pass.sh" > /home/dmin/qwen36-strata-project/prombase_launch.log 2>&1 < /dev/null &
for i in $(seq 1 480); do
  ps aux --width 250 | grep -q "promotion_base_pass" || { echo "base pass exited after $i polls"; exit 0; }
  sleep 15
done
echo "supervisor timeout (the pass may still be running)"
