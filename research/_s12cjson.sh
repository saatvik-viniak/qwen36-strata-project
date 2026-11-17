#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
for f in w5 w6 w12; do
  echo "$f.json -> $(grep -o '"decode_tps": [0-9.]*' "$WS/research/s12c/$f.json" | head -1)"
done
