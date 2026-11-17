#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
sleep 45
echo "== processes =="
ps aux --width 250 | grep -E "cand_q5k_runner|build_kit|ninja|apply_q5k" | grep -v grep || echo "(none)"
echo "== cand_q5k.log =="
cat "$WS/research/cand_q5k.log"
