#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== the promotion results so far =="
ls -l --time-style=+%H:%M "$WS/research/promotion/" 2>/dev/null
for f in empty.json ctx32k.json ctx128k.json; do
  p="$WS/research/promotion/$f"
  [ -f "$p" ] && echo "$f: $(grep -o "\"decode_tps\": [0-9.]*" "$p" | head -1)" || echo "$f: absent"
done
echo ""
echo "== the promotion log's empty cell line =="
grep -n "CELL empty\|empty measured" "$WS/research/promotion.log" | head -3
grep -o "\"decode_tps\": [0-9.]*" "$WS/research/promotion/empty.json" 2>/dev/null | head -1
echo ""
echo "== the primary agent's commit 1ab1b07 =="
cd "$WS" && git show --stat --format="%h %s | %ad" 1ab1b07 | head -14
