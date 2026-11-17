#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
sleep "${1:-420}"
echo "now: $(date -u +%F_%TZ)"
echo "== processes =="
ps aux --width 250 | grep -E "cand_q5k_runner|promotion_pass|solo_gate|bench\.py|serve_262k|native_expert" | grep -v grep || echo "(none)"
echo "== chain log tail =="
tail -12 "$WS/research/cand_q5k.log"
echo "== promotion log tail =="
tail -4 "$WS/research/promotion.log" 2>/dev/null
echo "== base pass log tail =="
tail -14 "$WS/research/promotion_base.log" 2>/dev/null || echo "(absent)"
echo "== markers =="
for f in cand_q5k.done promotion.done promotion_base.done; do [ -f "$WS/research/$f" ] && echo "$f: $(cat "$WS/research/$f")" || echo "$f: absent"; done
echo "== result files =="
ls "$WS/research/cand_q5k/cand/" "$WS/research/cand_q5k/control/" "$WS/research/promotion/" 2>/dev/null
echo "== supplement commits =="
git -C "$WS" log -3 --oneline 2>/dev/null
