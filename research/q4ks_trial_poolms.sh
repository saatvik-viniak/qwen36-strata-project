#!/bin/bash
# q4ks_trial_poolms.sh — trial T2: the poolms capture on the Q4_K_S champion config.
# Waits for T1's marker, serves the poolms binary (STRATA_POOLMS=1, everything else
# the champion config), settles 900 s, benches the empty cell (the pool-ms lines land
# in the engine log strata-qwen36-q4ks262.log; the bench's own rate checks the fprintf
# did not cost meaningful time), then restores the compose binary as the champion.
# Results: research/q4ks_trials/poolms/empty.json + q4ks_trial_poolms.done.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
BASE=http://127.0.0.1:30000
P=$WS/research/q4ks_trials/poolms
DONE=$WS/research/q4ks_trial_poolms.done
LOG=$WS/research/q4ks_trial_poolms.log
export MODEL_PATH=/models/qwen36-tokenizer
echo "== q4ks trial poolms up $(date -u +%F_%TZ) ==" > "$LOG"

# 0. wait for T1 to finish (the chain guarantees it; cap 3 h for safety)
for i in $(seq 1 720); do
  V=$(cat "$WS/research/q4ks_trial_mtpoff.done" 2>/dev/null)
  [ -n "$V" ] && break
  sleep 15
done
echo "T1 marker: $(cat "$WS/research/q4ks_trial_mtpoff.done" 2>/dev/null) $(date -u +%F_%TZ)" >> "$LOG"

mkdir -p "$P"
rm -f "$DONE"
cd /home/dmin/qwen36-strata-project || exit 1

# 1. serve the poolms binary (the script stops the old server itself)
setsid nohup bash "$WS/research/serve_262k_q4ks_poolms.sh" > /home/dmin/qwen36-strata-project/serve_poolms_launch.log 2>&1 < /dev/null &
if "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1; then
  echo "poolms server healthy $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "poolms server never healthy $(date -u +%F_%TZ)" >> "$LOG"
  echo "server_failed" > "$DONE"; exit 1
fi

# 2. settle 900 s, then the empty cell (NO watchdog)
echo "settling 900 s $(date -u +%F_%TZ)" >> "$LOG"
sleep 900
echo "settle done $(date -u +%F_%TZ)" >> "$LOG"
echo "== CELL empty $(date -u +%F_%TZ) ==" >> "$LOG"
if "$PY" /home/dmin/qwen36-strata-kit/run/bench.py --base-url "$BASE" --model qwen3.6-35b-a3b \
     --prompt-tokens 1 --output-tokens 512 --concurrency 1 \
     --out "$P/empty.json" >> "$LOG" 2>&1 \
   && [ -s "$P/empty.json" ] && grep -q decode_tps "$P/empty.json"; then
  echo "bench empty measured $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "bench empty FAILED $(date -u +%F_%TZ)" >> "$LOG"
fi

# 3. harvest the pool-ms lines into the results dir, then restore the champion
tail -c 2000000 /home/dmin/qwen36-strata-project/strata-qwen36-q4ks262.log | grep 'pool-ms' > "$P/poolms_lines.txt" 2>/dev/null
echo "pool-ms lines captured: $(wc -l < "$P/poolms_lines.txt" 2>/dev/null)" >> "$LOG"
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
setsid nohup bash "$WS/research/serve_262k_q4ks.sh" > /home/dmin/qwen36-strata-project/serve_q4ks_launch.log 2>&1 < /dev/null &
"$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1 \
  && echo "champion restored $(date -u +%F_%TZ)" >> "$LOG" \
  || echo "champion restore NOT healthy $(date -u +%F_%TZ)" >> "$LOG"
if [ -s "$P/empty.json" ]; then
  echo "ok: poolms trial complete $(date -u +%F_%TZ)" >> "$LOG"
  echo "bench_complete" > "$DONE"
else
  echo "poolms_bench_failed" > "$DONE"
fi
