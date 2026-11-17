#!/bin/bash
# trial_runner.sh — run trials sequentially, detached-safe. Usage: bash trial_runner.sh TRIAL...
# Each trial: start its server variant, wait health, bench empty/ctx32k/ctx128k
# (one invocation per cell — bench.py warms internally), with a VRAM watchdog.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
KIT=/home/dmin/qwen36-strata-kit
PY=/opt/strata/venv/bin/python
export MODEL_PATH=/models/qwen36-tokenizer
BASE=http://127.0.0.1:30000
DONE=$WS/research/trial_runner.done
rm -f "$DONE"
mkdir -p "$WS/research/trials"

# serialize with the baseline benches: wait for the lean bench to finish first
LEAN=$WS/research/lean_bench.done
for i in $(seq 1 120); do
  [ -f "$LEAN" ] && break
  echo "waiting for lean_bench.done ($i) $(date -u +%F_%TZ)"
  sleep 30
done
[ -f "$LEAN" ] || { echo "lean bench never finished; aborting trials" > "$DONE"; exit 1; }

for T in "$@"; do
  case "$T" in
    nommq) SRV=$WS/research/serve_262k_nommq.sh ;;
    ct5)   SRV=$WS/research/serve_262k_ct5.sh ;;
    mtp3)  SRV=$WS/research/serve_262k_mtp3.sh ;;
    *) echo "unknown trial $T"; continue ;;
  esac
  echo "== TRIAL $T: server $(date -u +%F_%TZ) =="
  setsid nohup bash "$SRV" > /home/dmin/qwen36-strata-project/trial_server.log 2>&1 < /dev/null &
  if "$PY" "$KIT/run/wait_health.py" "$BASE/health" 900; then
    echo "server healthy for $T $(date -u +%F_%TZ)"
  else
    echo "fail: $T server never healthy" | tee -a "$WS/research/trial_runner.log"
    continue
  fi
  mkdir -p "$WS/research/trials/$T"
  # VRAM watchdog: sample every 3 s, abort the trial if peak > 7.9 GiB
  ( while true; do
      V=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null)
      [ -n "$V" ] && echo "$(date -u +%F_%TZ) $V" >> "$WS/research/trials/$T/vram.log"
      if [ -n "$V" ] && [ "$V" -gt 8090 ]; then
        echo "WATCHDOG: $V MiB > 8090 at $(date -u +%F_%TZ)" >> "$WS/research/trials/$T/vram.log"
        pkill -TERM -f 'bench.py' 2>/dev/null
        break
      fi
      sleep 3
    done ) &
  WATCHDOG=$!
  for CELL in empty ctx32k ctx128k; do
    case "$CELL" in
      empty)   PT=1 ;;
      ctx32k)  PT=32768 ;;
      ctx128k) PT=131072 ;;
    esac
    echo "== TRIAL $T CELL $CELL $(date -u +%F_%TZ) =="
    "$PY" "$KIT/run/bench.py" --base-url "$BASE" --model qwen3.6-35b-a3b \
      --prompt-tokens "$PT" --output-tokens 512 --concurrency 1 \
      --out "$WS/research/trials/$T/$CELL.json" || echo "bench $T/$CELL FAILED"
  done
  kill -TERM $WATCHDOG 2>/dev/null
  echo "== TRIAL $T done $(date -u +%F_%TZ) =="
done
# end in the champion state: restart the frozen-baseline server
setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
echo "ok: all trials done; baseline server restarting $(date -u +%F_%TZ)" > "$DONE"
