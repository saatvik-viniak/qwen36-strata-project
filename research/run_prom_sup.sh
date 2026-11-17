#!/bin/bash
# run_prom_sup.sh — supervisor for promotion_pass.sh (v2), same pattern as
# run_v6_sup.sh: the background shell job holds the wsl client alive while the
# pass runs detached; the job completes when the pass exits (its expected life:
# the v6 wait + serve + settle 900 s + 3 cells ~ 2 h). NOTE for the launcher:
# do NOT pass a timeout to the background shell call — a 30 s timeout killed
# the v6 supervisor (SIGTERM at 30 s) while the setsid'd runner survived.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
setsid nohup bash "$WS/research/promotion_pass.sh" > /home/dmin/qwen36-strata-project/promotion_launch.log 2>&1 < /dev/null &
for i in $(seq 1 600); do
  ps aux --width 250 | grep -q "promotion_pass" || { echo "promotion pass exited after $i polls"; exit 0; }
  sleep 15
done
echo "supervisor timeout (the pass may still be running)"
