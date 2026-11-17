#!/bin/bash
# Q4_K_S reference data points on the RUNNING 65536-ctx server (MTP 0, w=5, KV int4,
# slots 23/layer, the compose binary, STRATA_KQ256 unset). NOT the mission baseline:
# a serving-config reference + bench-pipeline validation for the Q4_K_S redirect.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
KIT=/home/dmin/qwen36-strata-kit
PY=/opt/strata/venv/bin/python
export MODEL_PATH=/models/qwen36-tokenizer
export BASE_URL=http://127.0.0.1:30000
mkdir -p "$WS/research/q4ks_ref"
echo "== binary md5 =="
md5sum /home/dmin/qwen36-strata-project/out/strata
FAIL=0
for CELL in empty ctx32k; do
  case "$CELL" in
    empty)  PT=1 ;;
    ctx32k) PT=32768 ;;
  esac
  echo "== REF CELL $CELL $(date -u +%F_%TZ) =="
  if "$PY" "$KIT/run/bench.py" --base-url "$BASE_URL" --model qwen3.6-35b-a3b \
       --prompt-tokens "$PT" --output-tokens 512 --concurrency 1 \
       --out "$WS/research/q4ks_ref/$CELL.json" >> "$WS/research/q4ks_ref/bench.log" 2>&1 \
     && [ -s "$WS/research/q4ks_ref/$CELL.json" ] && grep -q decode_tps "$WS/research/q4ks_ref/$CELL.json"; then
    echo "ok $CELL $(date -u +%F_%TZ)"
  else
    echo "FAILED $CELL $(date -u +%F_%TZ)"; FAIL=1
  fi
done
if [ "$FAIL" -eq 0 ]; then echo REF_COMPLETE; else echo REF_FAILED; fi
