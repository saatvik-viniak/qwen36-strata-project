#!/bin/bash
# promotion_pass.sh — the CLEAN promotion bench for the compose candidate (q5k+uint4),
# per the handoff #7 protocol: no watchdog at all (the 3-s poll stole ~1 core on WSL2
# and confounded the uint4 empty/ctx32k cells), a ~15 min post-load settle (the
# disturbance fix), 3 cells against the CLEAN anchors (empty 21.89, ctx32k 19.52,
# ctx128k 11.73; repeats 21.86/11.66). Waits for research/cand_q5k.done == bench_complete
# (the q5k chain's gates + A/B must pass first). Leaves the champion serving; the
# numbers land in research/promotion/ and the VERDICT is the primary agent's.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
BASE=http://127.0.0.1:30000
P=$WS/research/promotion
DONE=$WS/research/promotion.done
LOG=$WS/research/promotion.log
echo "== promotion_pass up $(date -u +%F_%TZ) ==" > "$LOG"

# 0. wait for the q5k chain (up to 2 h)
for i in $(seq 1 240); do
  [ -f "$WS/research/cand_q5k.done" ] && break
  sleep 30
done
VERDICT=$(cat "$WS/research/cand_q5k.done" 2>/dev/null)
[ "$VERDICT" = "bench_complete" ] || { echo "q5k chain did not complete ($VERDICT); aborting" >> "$LOG"; exit 1; }
echo "q5k chain complete $(date -u +%F_%TZ)" >> "$LOG"

mkdir -p "$P"
rm -f "$DONE"
cd /home/dmin/qwen36-strata-project 2>/dev/null || cd /home/dmin/qwen36-strata-project || exit 1

# 1. serve the compose binary (STRATA_KQ256=1)
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
cp /home/dmin/qwen36-strata-project/out/strata_q5k_cand /home/dmin/qwen36-strata-project/out/strata
setsid nohup bash "$WS/research/serve_262k_q5k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
"$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1 || {
  echo "server never healthy" >> "$LOG"; bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
  cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata
  setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
  echo "restore_failed" > "$DONE"; exit 1; }
echo "compose server healthy $(date -u +%F_%TZ)" >> "$LOG"

# 2. the settle: the first request after a load runs in a degraded window decaying
#    over ~15+ min (the uint4 chain's finding); both passes of the A/B carried the same
#    treatment, but THIS pass compares against the clean anchors, so it must settle.
echo "settling 900 s $(date -u +%F_%TZ)" >> "$LOG"
sleep 900
echo "settle done $(date -u +%F_%TZ)" >> "$LOG"

# 3. the 3 cells, NO watchdog (the compose binary's peak is measured ~7.35 GiB; a hard
#    OOM fails the bench loudly)
for CELL in empty ctx32k ctx128k; do
  case "$CELL" in
    empty)   PT=1 ;;
    ctx32k)  PT=32768 ;;
    ctx128k) PT=131072 ;;
  esac
  echo "== CELL $CELL $(date -u +%F_%TZ) ==" >> "$LOG"
  "$PY" /home/dmin/qwen36-strata-kit/run/bench.py --base-url "$BASE" --model qwen3.6-35b-a3b \
    --prompt-tokens "$PT" --output-tokens 512 --concurrency 1 \
    --out "$P/$CELL.json" >> "$LOG" 2>&1 || echo "bench $CELL FAILED" >> "$LOG"
done

# 4. leave the champion serving; the verdict is the primary agent's
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata
setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
echo "champion restored $(date -u +%F_%TZ)" >> "$LOG"
echo "ok: promotion pass complete $(date -u +%F_%TZ)" >> "$LOG"
echo "bench_complete" > "$DONE"
