#!/bin/bash
# q4ks_baseline_pass.sh — the Q4_K_S redirect's mission-protocol baseline.
# User directive (2026-11-17): serve the Q4_K_S quant on disk (NOT the Q5_K_S),
# confirm the compatible KV cache, then climb. This pass records the baseline the
# 2.00x targets anchor to: the champion serving config (compose binary +
# STRATA_KQ256=1, MTP 2, greedy sampler, CT 8, KV int4, PREFILL 1024) at 262k
# server context, then empty / ctx32k / ctx128k cells (512-token greedy decode,
# concurrency 1), with the promotion protocol's hygiene:
#   - waits for the q4ks ref bench to release the server (q4ks_ref_launch.log's
#     REF_COMPLETE / REF_FAILED; 30 min cap, proceeds with a note otherwise),
#   - serve -> wait health (900 s cap) -> settle 900 s (the post-load disturbance),
#   - 3 cells, NO watchdog anywhere (the 3 s poll stole a core on WSL2),
#   - MODEL_PATH exported, bench failures counted -> truthful markers.
# Results: research/q4ks_baseline/<cell>.json; marker research/q4ks_baseline.done.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
BASE=http://127.0.0.1:30000
P=$WS/research/q4ks_baseline
DONE=$WS/research/q4ks_baseline.done
LOG=$WS/research/q4ks_baseline.log
export MODEL_PATH=/models/qwen36-tokenizer
FAIL=0
echo "== q4ks baseline pass up $(date -u +%F_%TZ) ==" > "$LOG"

# 0. wait for the ref bench to release the port (it is benching the 64k server)
REF=unknown
for i in $(seq 1 120); do
  R=$(grep -o -e REF_COMPLETE -e REF_FAILED /home/dmin/qwen36-strata-project/q4ks_ref_launch.log 2>/dev/null | head -1)
  [ -n "$R" ] && { REF=$R; break; }
  sleep 15
done
echo "ref bench state: $REF $(date -u +%F_%TZ)" >> "$LOG"

mkdir -p "$P"
rm -f "$DONE"
cd /home/dmin/qwen36-strata-project || exit 1

# 1. serve the Q4_K_S model at the champion config (the script stops the old server)
setsid nohup bash "$WS/research/serve_262k_q4ks.sh" > /home/dmin/qwen36-strata-project/serve_q4ks_launch.log 2>&1 < /dev/null &
if "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1; then
  echo "q4ks 262k server healthy $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "q4ks server never healthy $(date -u +%F_%TZ)" >> "$LOG"
  echo "server_failed" > "$DONE"; exit 1
fi

# 2. the settle: the first request after a load runs in a degraded window decaying
#    over ~15+ min (the uint4 chain's finding; the promotion protocol's fix)
echo "settling 900 s $(date -u +%F_%TZ)" >> "$LOG"
sleep 900
echo "settle done $(date -u +%F_%TZ)" >> "$LOG"

# 3. the 3 cells, NO watchdog (an OOM fails the bench loudly -> a truthful marker)
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

# 4. leave the Q4_K_S champion config serving for the trials
echo "q4ks baseline pass complete $(date -u +%F_%TZ)" >> "$LOG"
if [ "$FAIL" -eq 0 ]; then
  echo "bench_complete" > "$DONE"
else
  echo "PASS FAILED - a lying done-marker poisons every reader $(date -u +%F_%TZ)" >> "$LOG"
  echo "q4ks_baseline_failed" > "$DONE"
fi
