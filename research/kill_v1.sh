#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== before =="
ps aux --width 250 | grep -E "promotion_pass|wait_health" | grep -v grep || echo "(no promotion processes)"
kill 91468 2>/dev/null && echo "killed 91468" || echo "91468 was not running"
pkill -f promotion_pass.sh 2>/dev/null && echo "pkilled promotion_pass.sh" || echo "(no promotion_pass match)"
pkill -f wait_health.py 2>/dev/null && echo "pkilled wait_health" || echo "(no wait_health match)"
sleep 1
echo "== after =="
ps aux --width 250 | grep -E "promotion_pass|wait_health" | grep -v grep || echo "(clean)"
# the honest done file: the v5 chain benched NOTHING (all four died on the empty MODEL_PATH)
echo "bench_failed_MODEL_PATH_v5" > "$WS/research/cand_q5k.done"
rm -f "$WS/research/promotion.done"
echo "cand_q5k.done: $(cat "$WS/research/cand_q5k.done")"
echo "promotion.done removed"
