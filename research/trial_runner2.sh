#!/bin/bash
# trial_runner2.sh — trials under the 30-min-per-bench budget (user rule, 2026-11-17).
# - nommq's ctx128k cell is SKIPPED (native-kernel prefill ~70 tok/s -> ~65 min > 30 min);
#   ct5 and mtp3 keep all cells (MMQ prefill ~260 tok/s -> ctx128k cell ~18-22 min).
# - Added trial D "mmqslots2": MMQ ON + --expert-slots 2 (mission lever B1 at the VRAM
#   edge; the need-check margin is ~13 MB, so the server may refuse — fast-fail handled).
# Usage: spawned detached by watch_and_swap.sh after nommq/ctx32k resolves.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
KIT=/home/dmin/qwen36-strata-kit
PY=/opt/strata/venv/bin/python
export MODEL_PATH=/models/qwen36-tokenizer
BASE=http://127.0.0.1:30000
DONE=$WS/research/trial_runner2.done
rm -f "$DONE"
mkdir -p "$WS/research/trials"

# wait_health_or_death URL SECONDS — 0 if healthy; 1 if the server process died
# (5 consecutive misses = dead; tolerates the stop->exec gap at the start).
wait_health_or_death () {
  local URL=$1 LIM=$2 i MISS=0
  for i in $(seq 1 "$LIM"); do
    H=$(curl -s -m 3 "$URL/health" 2>/dev/null)
    case "$H" in
      *'"loaded": true'*|*'"loaded":true'*) return 0 ;;
    esac
    if pgrep -f 'serve\.server' >/dev/null 2>&1; then MISS=0; else MISS=$((MISS+1)); fi
    [ "$MISS" -ge 5 ] && { echo "server process died before healthy (at ${i}s)"; return 1; }
    sleep 1
  done
  echo "server did not become healthy within ${LIM}s"
  return 1
}

run_trial () {  # run_trial TRIAL SERV_SCRIPT CELL...
  local T=$1; local SRV=$2; shift 2
  echo "== TRIAL $T: server $(date -u +%F_%TZ) =="
  setsid nohup bash "$SRV" > /home/dmin/qwen36-strata-project/trial_server.log 2>&1 < /dev/null &
  if wait_health_or_death "$BASE" 900; then
    echo "server healthy for $T $(date -u +%F_%TZ)"
  else
    echo "fail: $T server never healthy" | tee -a "$WS/research/trial_runner2.log"
    return
  fi
  mkdir -p "$WS/research/trials/$T"
  # VRAM watchdog: sample every 3 s, abort the bench if peak > 8090 MiB
  ( while true; do
      V=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null)
      [ -n "$V" ] && echo "$(date -u +%F_%TZ) $V" >> "$WS/research/trials/$T/vram.log"
      if [ -n "$V" ] && [ "$V" -gt 8090 ]; then
        echo "WATCHDOG: $V MiB > 8090 at $(date -u +%F_%TZ)" >> "$WS/research/trials/$T/vram.log"
        pkill -TERM -f 'bench\.py' 2>/dev/null
        break
      fi
      sleep 3
    done ) &
  local WATCHDOG=$!
  for CELL in "$@"; do
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
}

run_trial ct5  "$WS/research/serve_262k_ct5.sh"  empty ctx32k ctx128k
run_trial mtp3 "$WS/research/serve_262k_mtp3.sh" empty ctx32k ctx128k
run_trial mmqslots2 "$WS/research/serve_262k_mmqslots2.sh" empty ctx32k ctx128k
# end in the champion state: restart the frozen-baseline server
setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
echo "ok: trials 2 done; baseline server restarting $(date -u +%F_%TZ)" > "$DONE"
