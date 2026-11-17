#!/bin/bash
# bench_runner.sh — benches only (server 13411 already loading). Detached-safe.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
KIT=/home/dmin/qwen36-strata-kit
PY=/opt/strata/venv/bin/python
export MODEL_PATH=/models/qwen36-tokenizer
BASE=http://127.0.0.1:30000
DONE=$WS/research/bench_runner.done
rm -f "$DONE"

echo "== bench runner start $(date -u +%F_%TZ) =="
mkdir -p "$WS/research/baseline/pass2" "$WS/research/baseline/pass3"

# wait for the already-loading server (limit 20 min)
if "$PY" "$KIT/run/wait_health.py" "$BASE/health" 1200; then
  echo "server healthy $(date -u +%F_%TZ)"
else
  echo "fail: server never healthy $(date -u +%F_%TZ)" > "$DONE"
  exit 1
fi

bench_round() { # $1=cell $2=prompt_tokens $3=out_json
  echo "== WARMUP $1 $(date -u +%F_%TZ) =="
  "$PY" "$KIT/run/bench.py" --base-url "$BASE" --model qwen3.6-35b-a3b \
    --prompt-tokens "$2" --output-tokens 512 --concurrency 1 \
    --out /tmp/warmup_$1.json || echo "warmup $1 FAILED"
  echo "== MEASURED $1 $(date -u +%F_%TZ) =="
  "$PY" "$KIT/run/bench.py" --base-url "$BASE" --model qwen3.6-35b-a3b \
    --prompt-tokens "$2" --output-tokens 512 --concurrency 1 \
    --out "$3" || echo "measured $1 FAILED"
}

bench_round ctx32k 32768   "$WS/research/baseline/pass3/ctx32k.json"
bench_round ctx128k 131072 "$WS/research/baseline/pass2/ctx128k.json"
bench_round ctx128k 131072 "$WS/research/baseline/pass3/ctx128k.json"

echo "ok: all bench rounds done $(date -u +%F_%TZ)" > "$DONE"
echo "== bench runner end $(date -u +%F_%TZ) =="
