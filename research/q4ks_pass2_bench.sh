#!/bin/bash
# q4ks_pass2_bench.sh — the Q4_K_S drift-bound second pass (bench-only, the champion
# serving): the 3 mission-protocol cells against the ALREADY-SERVING champion (the
# compose binary 8833c30b, MTP 2, greedy sampler, CT 8, KV int4, STRATA_KQ256=1,
# 262k server ctx). The ONLY purpose: bound the day-drift for pass 1's comparators
# (empty +4.4% / ctx32k +5.8% / ctx128k +3.8% vs the compose champion's same-day
# cells, qualified). The protocol note recorded: pass 1 served fresh + settled 900 s;
# pass 2 measures the T2-RESTORED champion after a 900-s settle from its own load —
# the same champion config, the same bench invocations, no watchdog.
# Gates: T2's done marker present; the champion healthy on 30000; the settle 900 s
# after the champion's health. Results: research/q4ks_baseline_pass2/<cell>.json +
# q4ks_pass2.done (bench_complete | pass2_bench_failed).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
BASE=http://127.0.0.1:30000
P=$WS/research/q4ks_baseline_pass2
DONE=$WS/research/q4ks_pass2.done
LOG=$WS/research/q4ks_pass2.log
export MODEL_PATH=/models/qwen36-tokenizer
FAIL=0
echo "== q4ks pass2 up $(date -u +%F_%TZ) ==" > "$LOG"

# 0. wait for T2's marker (max 60 min), record it
V=""
for i in $(seq 1 240); do
  V=$(cat "$WS/research/q4ks_trial_poolms.done" 2>/dev/null)
  [ -n "$V" ] && break
  sleep 15
done
if [ -z "$V" ] || [ "$V" != "bench_complete" ]; then
  echo "T2 marker missing or not bench_complete ('$V') - aborting honestly $(date -u +%F_%TZ)" >> "$LOG"
  echo "pass2_aborted" > "$DONE"; exit 1
fi
echo "T2 marker: $V $(date -u +%F_%TZ)" >> "$LOG"

# 1. the champion healthy (T2's restore serves it; the health wait max 900 s)
if "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1; then
  echo "champion healthy $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "champion NOT healthy - aborting honestly $(date -u +%F_%TZ)" >> "$LOG"
  echo "pass2_aborted" > "$DONE"; exit 1
fi

# 2. the settle: 900 s from the champion's health (the fresh-load disturbance decays
#    ~15 min; the T2 restore loaded it minutes before this gate opened)
echo "settling 900 s $(date -u +%F_%TZ)" >> "$LOG"
sleep 900
echo "settle done $(date -u +%F_%TZ)" >> "$LOG"

# 3. the 3 cells, NO watchdog (the mission protocol)
mkdir -p "$P"
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

# 4. the truthful marker (the champion keeps serving; nothing to restore)
if [ "$FAIL" -eq 0 ]; then
  echo "ok: pass2 complete $(date -u +%F_%TZ)" >> "$LOG"
  echo "bench_complete" > "$DONE"
else
  echo "PASS FAILED - a lying done-marker poisons every reader $(date -u +%F_%TZ)" >> "$LOG"
  echo "pass2_bench_failed" > "$DONE"
fi
