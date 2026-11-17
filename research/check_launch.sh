#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
sleep 3
echo "== processes =="
ps aux --width 250 | grep -E "cand_q5k_runner|promotion_pass" | grep -v grep || echo "(none visible)"
echo "== cand_q5k_launch.log =="
cat /home/dmin/qwen36-strata-project/cand_q5k_launch.log 2>/dev/null || echo "(absent)"
echo "== cand_q5k.log (first lines) =="
head -5 "$WS/research/cand_q5k.log" 2>/dev/null || echo "(absent)"
