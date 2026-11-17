#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
sleep 20
echo "== promotion.log (v2 up?) =="
cat "$WS/research/promotion.log" 2>/dev/null || echo "(absent)"
echo "== chain log tail (parity result?) =="
tail -6 "$WS/research/cand_q5k.log"
echo "== processes =="
ps aux --width 250 | grep -E "promotion_pass|cand_q5k_runner|solo_gate|bench" | grep -v grep || echo "(none)"
