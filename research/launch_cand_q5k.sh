#!/bin/bash
# launch_cand_q5k.sh — detach cand_q5k_runner.sh so it survives this client.
# The launcher keeps the client alive ~4 s past the spawn (the WSL trap).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
setsid nohup bash "$WS/research/cand_q5k_runner.sh" > /home/dmin/qwen36-strata-project/cand_q5k_launch.log 2>&1 < /dev/null &
sleep 4
echo "launched: $(ps aux --width 250 | grep cand_q5k_runner | grep -v grep | head -2)"
