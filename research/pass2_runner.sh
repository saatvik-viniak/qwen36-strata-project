#!/bin/bash
# pass2_runner.sh — detached baseline completion (run inside WSL).
# Completes the pass-2/pass-3 measured rounds that the killed background job missed:
#   ctx32k pass-3, ctx128k pass-2, ctx128k pass-3 (each: 1 warmup + 1 measured round).
# All output to the Windows checkout so it survives WSL-side state.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
KIT=/home/dmin/qwen36-strata-kit
PY=/opt/strata/venv/bin/python
export MODEL_PATH=/models/qwen36-tokenizer
BASE=http://127.0.0.1:30000
LOG=$WS/research/pass2_runner.log
DONE=$WS/research/pass2_runner.done
rm -f "$DONE"

echo "== runner start $(date -u +%F_%TZ) =="

# --- GPU state before (skill ground rule 3: record the state) ---
echo "== GPU before ==" >> "$LOG" 2>&1
nvidia-smi --query-gpu=name,memory.total,memory.used,utilization.gpu --format=csv >> "$LOG" 2>&1

# --- 1. start the 262k int4 server, detached so it survives the client ---
cd /home/dmin/qwen36-strata-project || { echo "no clone dir" >> "$LOG"; exit 1; }
setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
echo "server launched (setsid nohup), pid $!"

# --- 2. wait for health (engine load at 262k takes ~5-6 min) ---
if "$PY" "$KIT/run/wait_health.py" "$BASE/health" 1200; then
  echo "server healthy $(date -u +%F_%TZ)"
else
  echo "SERVER NEVER BECAME HEALTHY" | tee -a "$LOG"
  echo "fail: server never healthy $(date -u +%F_%TZ)" > "$DONE"
  exit 1
fi

mkdir -p "$WS/research/baseline/pass2" "$WS/research/baseline/pass3"

# --- 3. bench: each round = 1 warmup (discarded, /tmp) + 1 measured ---
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

# order: cheap cell first, then the two 128k rounds
bench_round ctx32k 32768  "$WS/research/baseline/pass3/ctx32k.json"
bench_round ctx128k 131072 "$WS/research/baseline/pass2/ctx128k.json"
bench_round ctx128k 131072 "$WS/research/baseline/pass3/ctx128k.json"

echo "== GPU after ==" >> "$LOG" 2>&1
nvidia-smi --query-gpu=memory.used --format=csv >> "$LOG" 2>&1
echo "ok: all rounds done $(date -u +%F_%TZ)" > "$DONE"
echo "== runner end $(date -u +%F_%TZ) =="
