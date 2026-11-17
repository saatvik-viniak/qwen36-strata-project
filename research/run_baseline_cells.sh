#!/bin/bash
# Baseline protocol driver: bench cells one at a time against the running server.
# Usage: bash run_baseline_cells.sh CELL [CELL...]
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
KIT=/home/dmin/qwen36-strata-kit
PY=/opt/strata/venv/bin/python
export MODEL_PATH=/models/qwen36-tokenizer
export BASE_URL=http://127.0.0.1:30000
mkdir -p "$WS/research/baseline"
for CELL in "$@"; do
  case "$CELL" in
    empty)   PT=1 ;;
    ctx32k)  PT=32768 ;;
    ctx128k) PT=131072 ;;
    *) echo "unknown cell $CELL"; exit 1 ;;
  esac
  echo "== CELL $CELL (prompt $PT, output 512, concurrency 1, greedy) =="
  date -u +%F_%TZ
  "$PY" "$KIT/run/bench.py" \
    --base-url "$BASE_URL" \
    --model qwen3.6-35b-a3b \
    --prompt-tokens "$PT" \
    --output-tokens 512 \
    --concurrency 1 \
    --out "$WS/research/baseline/${CELL}${OUTSUFFIX:-}.json"
  echo "== done $CELL =="
  date -u +%F_%TZ
done
echo ALL_CELLS_DONE
