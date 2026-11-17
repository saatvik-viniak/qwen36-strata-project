#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
P="$WS/research/promotion"
echo "== the promotion dir (all results) =="
ls -l --time-style=+%m-%d_%H:%M "$P"/*.json 2>/dev/null
echo ""
for f in empty.json ctx32k.json ctx128k.json base_empty.json base_ctx32k.json base_ctx128k.json; do
  if [ -f "$P/$f" ]; then
    echo "$f -> $(grep -o '"decode_tps": [0-9.]*' "$P/$f" | head -1) | prefill $(grep -o '"prefill_tps": [0-9.]*' "$P/$f" | head -1)"
  else
    echo "$f -> ABSENT"
  fi
done
echo ""
echo "== the promotion log's ctx128k cell line (exact compose value) =="
grep -A1 "CELL ctx128k" "$WS/research/promotion.log" | head -4
