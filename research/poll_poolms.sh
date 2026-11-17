#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
sleep "${1:-300}"
echo "now: $(date -u +%F_%TZ)"
echo "== poolms.log tail =="
tail -12 "$WS/research/poolms.log" 2>/dev/null || echo "(absent)"
echo "== done marker =="
[ -f "$WS/research/poolms.done" ] && cat "$WS/research/poolms.done" || echo "(absent)"
echo "== poolms results =="
[ -s "$WS/research/poolms/empty.json" ] && grep -o '"decode_tps": [0-9.]*' "$WS/research/poolms/empty.json" | head -1 || echo "empty: (no result yet)"
