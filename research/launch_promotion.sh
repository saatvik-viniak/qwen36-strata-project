#!/bin/bash
# launch_promotion.sh — detach promotion_pass.sh (the WSL trap: keep the client alive 4 s).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
setsid nohup bash "$WS/research/promotion_pass.sh" > /home/dmin/qwen36-strata-project/promotion_launch.log 2>&1 < /dev/null &
sleep 4
echo "launched: $(ps aux --width 250 | grep promotion_pass | grep -v grep | head -1)"
