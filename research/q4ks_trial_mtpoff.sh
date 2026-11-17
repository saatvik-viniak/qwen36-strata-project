#!/bin/bash
# q4ks_trial_mtpoff.sh — trial T1 (S15-A): the MTP sampling-gate isolation on the
# Q4_K_S model at 262k. Chains on the baseline pass's marker, serves the MTP-off
# config (serve_262k_q4ks_mtpoff.sh — identical to the champion config except no
# SAMPLING export), settles 900 s, benches the 3 cells (512-token greedy, NO
# watchdog), then restores the champion (MTP-on) serving. Results:
# research/q4ks_trials/mtpoff/<cell>.json + q4ks_trial_mtpoff.done.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
BASE=http://127.0.0.1:30000
P=$WS/research/q4ks_trials/mtpoff
DONE=$WS/research/q4ks_trial_mtpoff.done
LOG=$WS/research/q4ks_trial_mtpoff.log
export MODEL_PATH=/models/qwen36-tokenizer
FAIL=0
echo "== q4ks trial mtpoff up $(date -u +%F_%TZ) ==" > "$LOG"

# 0. wait for the baseline pass to finish (max 90 min), record its marker
BM=absent
for i in $(seq 1 360); do
  V=$(cat "$WS/research/q4ks_baseline.done" 2>/dev/null)
  [ -n "$V" ] && { BM=$V; break; }
  sleep 15
done
echo "baseline marker: $BM $(date -u +%F_%TZ)" >> "$LOG"

mkdir -p "$P"
rm -f "$DONE"
cd /home/dmin/qwen36-strata-project || exit 1

# 1. serve the MTP-off config (the script stops the old server itself)
setsid nohup bash "$WS/research/serve_262k_q4ks_mtpoff.sh" > /home/dmin/qwen36-strata-project/serve_mtpoff_launch.log 2>&1 < /dev/null &
if "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1; then
  echo "mtpoff server healthy $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "mtpoff server never healthy $(date -u +%F_%TZ)" >> "$LOG"
  echo "server_failed" > "$DONE"; exit 1
fi

# 2. the settle (the post-load disturbance decays ~15+ min)
echo "settling 900 s $(date -u +%F_%TZ)" >> "$LOG"
sleep 900
echo "settle done $(date -u +%F_%TZ)" >> "$LOG"

# 3. the 3 cells, NO watchdog
for CELL in empty ctx32k ctx128k; do
  case "$CELL" in
    empty)   PT=1 ;;
    ctx32k)  PT=32768 ;;
    ctx128k) PT=131072 ;;
  esac
  echo "== CELL $CELL $(date -u +%F_%TZ) ==" >> "$LOG"
  if "$PY" /home/dmin/qwen36-strata-kit/run/bench.py --base-url "$BASE" --model qwen3.6-35b-a3b \
       --prompt-tokens "$PT" --output-tokens 512 --concurrency 1 \
       --out "$P/$CELL.json" >> "$LOG" 2>&1 \
     && [ -s "$P/$CELL.json" ] && grep -q decode_tps "$P/$CELL.json"; then
    echo "bench $CELL measured $(date -u +%F_%TZ)" >> "$LOG"
  else
    echo "bench $CELL FAILED $(date -u +%F_%TZ)" >> "$LOG"; FAIL=1
  fi
done

# 4. restore the champion (MTP-on) serving
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
setsid nohup bash "$WS/research/serve_262k_q4ks.sh" > /home/dmin/qwen36-strata-project/serve_q4ks_launch.log 2>&1 < /dev/null &
"$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1 \
  && echo "champion restored $(date -u +%F_%TZ)" >> "$LOG" \
  || echo "champion restore NOT healthy $(date -u +%F_%TZ)" >> "$LOG"
if [ "$FAIL" -eq 0 ]; then
  echo "ok: mtpoff trial complete $(date -u +%F_%TZ)" >> "$LOG"
  echo "bench_complete" > "$DONE"
else
  echo "PASS FAILED - a lying done-marker poisons every reader $(date -u +%F_%TZ)" >> "$LOG"
  echo "mtpoff_bench_failed" > "$DONE"
fi
