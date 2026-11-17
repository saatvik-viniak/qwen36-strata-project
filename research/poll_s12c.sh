#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
sleep "${1:-420}"
echo "now: $(date -u +%F_%TZ)"
echo "== s12c.log tail =="
tail -14 "$WS/research/s12c.log" 2>/dev/null || echo "(absent)"
echo "== done marker =="
[ -f "$WS/research/s12c.done" ] && cat "$WS/research/s12c.done" || echo "(absent)"
echo "== results =="
for f in w5 w6 w12; do
  p="$WS/research/s12c/$f.json"
  [ -s "$p" ] && echo "$f: $(grep -o '"decode_tps": [0-9.]*' "$p" | head -1)" || echo "$f: (no result yet)"
done
echo "== supplement commits =="
git -C "$WS" log -2 --oneline
