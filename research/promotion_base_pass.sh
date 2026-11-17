#!/bin/bash
# promotion_base_pass.sh — the BASE leg of the promotion decision (the supplementary
# agent's window-conflict demand, SUGGESTIONS.MD ~09:42Z): the promotion ledger must
# compare compose-clean vs base-clean SAME-PROTOCOL SAME-DAY before a default-changing
# decision (the repo's rule: "show the numbers with what they were measured on").
#
# Protocol = promotion_pass v2's, with the binary swapped and the load REUSED: the
# champion server that v2's restore just launched (health ~10:05Z) serves the base
# binary (out/strata == strata_q5k_base, cmp-verified); both passes get the same
# 900-s-post-health settle; the same cell order (empty, ctx32k, ctx128k); NO watchdog;
# MODEL_PATH exported; bench failures counted → the truthful marker
# promotion_base_bench_failed. Results: research/promotion/base_{cell}.json.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
BASE=http://127.0.0.1:30000
P=$WS/research/promotion
DONE=$WS/research/promotion_base.done
LOG=$WS/research/promotion_base.log
export MODEL_PATH=/models/qwen36-tokenizer
FAIL=0
echo "== promotion_base_pass up $(date -u +%F_%TZ) ==" > "$LOG"
mkdir -p "$P"
rm -f "$DONE"

# 0. the binary check: out/strata must BE the base binary (v2's restore cp'd it)
if ! cmp -s /home/dmin/qwen36-strata-project/out/strata /home/dmin/qwen36-strata-project/out/strata_q5k_base; then
  echo "out/strata is not the base binary; aborting" >> "$LOG"
  echo "aborted" > "$DONE"
  exit 1
fi
echo "base binary verified on out/strata $(date -u +%F_%TZ)" >> "$LOG"

# 1. wait for the current champion server's health (v2's restore load); if it never
#    comes healthy, serve the base fresh (the protocol's fallback)
if "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1; then
  echo "base server healthy (the reused load) $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "server never healthy; serving the base fresh" >> "$LOG"
  bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
  cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata
  setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
  if "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1; then
    echo "base server healthy (fresh) $(date -u +%F_%TZ)" >> "$LOG"
  else
    echo "server never healthy (fresh serve too) $(date -u +%F_%TZ)" >> "$LOG"
    echo "serve_failed" > "$DONE"
    exit 1
  fi
fi

# 2. the settle: the same 900-s-post-health treatment the compose pass got
echo "settling 900 s $(date -u +%F_%TZ)" >> "$LOG"
sleep 900
echo "settle done $(date -u +%F_%TZ)" >> "$LOG"

# 3. the 3 cells, NO watchdog, the same order (the protocol symmetry)
for CELL in empty ctx32k ctx128k; do
  case "$CELL" in
    empty)   PT=1 ;;
    ctx32k)  PT=32768 ;;
    ctx128k) PT=131072 ;;
  esac
  echo "== CELL $CELL $(date -u +%F_%TZ) ==" >> "$LOG"
  if "$PY" /home/dmin/qwen36-strata-kit/run/bench.py --base-url "$BASE" --model qwen3.6-35b-a3b \
       --prompt-tokens "$PT" --output-tokens 512 --concurrency 1 \
       --out "$P/base_$CELL.json" >> "$LOG" 2>&1 \
     && [ -s "$P/base_$CELL.json" ] && grep -q decode_tps "$P/base_$CELL.json" 2>/dev/null; then
    echo "bench $CELL measured $(date -u +%F_%TZ)" >> "$LOG"
  else
    echo "bench $CELL FAILED" >> "$LOG"; FAIL=1
  fi
done

# 4. the champion is serving (the reused server); the verdict is the primary agent's
if [ "$FAIL" -eq 0 ]; then
  echo "ok: base pass complete $(date -u +%F_%TZ)" >> "$LOG"
  echo "bench_complete" > "$DONE"
else
  echo "BASE PASS FAILED — the marker never lies $(date -u +%F_%TZ)" >> "$LOG"
  echo "promotion_base_bench_failed" > "$DONE"
fi
