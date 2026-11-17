#!/bin/bash
# temp helper: quick verdict check before closing the turn
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
R="$WS/research"
date -u +%H:%M:%SZ
for f in cand/empty.json control/empty.json; do
  p="$R/cand_q5k/$f"
  [ -f "$p" ] && echo "$f: $(grep -o "\"decode_tps\": [0-9.]*" "$p" | head -1)" || echo "$f: absent"
done
tail -3 "$R/cand_q5k.log"
