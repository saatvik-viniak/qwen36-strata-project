#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
sleep 60
echo "== processes =="
ps aux --width 250 | grep -E "cand_q5k_runner|build_kit|ninja|cmake|native_expert_parity|solo_gate" | grep -v grep || echo "(none)"
echo "== cand_q5k.log =="
tail -25 "$WS/research/cand_q5k.log"
