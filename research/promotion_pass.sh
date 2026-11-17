#!/bin/bash
# promotion_pass.sh v2 — the CLEAN promotion bench for the compose candidate
# (q5k + uint4, STRATA_KQ256=1), after the q5k chain v6 passes its gates + A/B.
#
# v1's defects (the post-mortem, SUGGESTIONS.MD "SECOND URGENT" + the harvest):
# it triggered on the v5 chain's VOID bench_complete marker without verifying any
# results exist, served out/strata_q5k_cand == byte_loop as the "compose" (the
# compose binary had been overwritten by the no-op cp), and had no MODEL_PATH —
# all 3 cells crashed on HFValidationError('') and it wrote a VOID bench_complete
# into promotion.done. The MODEL_PATH defect ironically protected the uint4 +52%
# claim: the false "compose = neutral" verdict never materialized.
#
# v2 (per SUGGESTIONS.MD's fix list):
#   (1) the trigger verifies the RESULTS EXIST (cand/ and control/ empty.json from
#       the v6 A/B) AND cand_q5k.done == bench_complete (v6's truthful marker);
#   (2) the compose binary must DIFFER from the base before serving (cmp -s);
#   (3) export MODEL_PATH=/models/qwen36-tokenizer;
#   (4) bench failures counted → a truthful marker (promotion_bench_failed);
#       bench_complete only if all 3 cells measured;
#   (5) the GOOD design stays: serve → wait health → settle 900 s (the post-load
#       disturbance decays ~15+ min and scales with the preceding 21-GiB load
#       cycles) → 3 cells (empty, ctx32k, ctx128k), NO watchdog anywhere (the
#       3-s poll stole ~1 core on WSL2 and confounded the uint4 empty/ctx32k
#       cells) → the champion restored. The verdict is the primary agent's,
#       per cell vs the clean anchors (empty 21.89, ctx32k 19.52, ctx128k 11.73;
#       repeats 21.86/11.66) and the same-day A/B.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
BASE=http://127.0.0.1:30000
P=$WS/research/promotion
DONE=$WS/research/promotion.done
LOG=$WS/research/promotion.log
export MODEL_PATH=/models/qwen36-tokenizer
FAIL=0
echo "== promotion_pass v2 up $(date -u +%F_%TZ) ==" > "$LOG"

# 0. wait for the q5k chain v6: the truthful marker AND the A/B results on disk
for i in $(seq 1 240); do
  V=$(cat "$WS/research/cand_q5k.done" 2>/dev/null)
  [ "$V" = "bench_complete" ] && break
  sleep 30
done
V=$(cat "$WS/research/cand_q5k.done" 2>/dev/null)
[ "$V" = "bench_complete" ] || { echo "q5k chain did not complete ($V); aborting" >> "$LOG"; echo "aborted" > "$DONE"; exit 1; }
if [ ! -s "$WS/research/cand_q5k/cand/empty.json" ] || [ ! -s "$WS/research/cand_q5k/control/empty.json" ]; then
  echo "the A/B results are missing; the marker lies; aborting" >> "$LOG"
  echo "aborted" > "$DONE"
  exit 1
fi
echo "q5k chain complete + A/B results verified $(date -u +%F_%TZ)" >> "$LOG"

mkdir -p "$P"
rm -f "$DONE"
cd /home/dmin/qwen36-strata-project || exit 1

# 1. the binary-level check: the compose candidate must DIFFER from the champion
if cmp -s /home/dmin/qwen36-strata-project/out/strata_q5k_cand /home/dmin/qwen36-strata-project/out/strata_q5k_base; then
  echo "TAUTOLOGY: the compose binary == the champion; aborting" >> "$LOG"
  echo "aborted" > "$DONE"
  exit 1
fi
echo "compose binary verified DISTINCT from the base $(date -u +%F_%TZ)" >> "$LOG"

serve_compose () {
  bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
  cp /home/dmin/qwen36-strata-project/out/strata_q5k_cand /home/dmin/qwen36-strata-project/out/strata
  setsid nohup bash "$WS/research/serve_262k_q5k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
  if "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1; then
    echo "compose server healthy $(date -u +%F_%TZ)" >> "$LOG"; return 0
  fi
  echo "compose server never healthy $(date -u +%F_%TZ)" >> "$LOG"; return 1
}

# 2. serve the compose binary, then the settle: the first request after a load
#    runs in a degraded window decaying over ~15+ min (the uint4 chain's finding)
serve_compose || {
  echo "compose serve failed" >> "$LOG"
  bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
  cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata
  setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
  echo "restore_failed" > "$DONE"; exit 1; }
echo "settling 900 s $(date -u +%F_%TZ)" >> "$LOG"
sleep 900
echo "settle done $(date -u +%F_%TZ)" >> "$LOG"

# 3. the 3 cells, NO watchdog (the compose binary's peak is measured ~7.35 GiB;
#    a hard OOM fails the bench loudly — and now loudly means a truthful marker)
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
     && [ -s "$P/$CELL.json" ] && grep -q decode_tps "$P/$CELL.json" 2>/dev/null; then
    echo "bench $CELL measured $(date -u +%F_%TZ)" >> "$LOG"
  else
    echo "bench $CELL FAILED" >> "$LOG"; FAIL=1
  fi
done

# 4. leave the champion serving; the verdict is the primary agent's
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata
setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
echo "champion restored $(date -u +%F_%TZ)" >> "$LOG"
if [ "$FAIL" -eq 0 ]; then
  echo "ok: promotion pass complete $(date -u +%F_%TZ)" >> "$LOG"
  echo "bench_complete" > "$DONE"
else
  echo "PASS FAILED — a lying done-marker poisons every reader $(date -u +%F_%TZ)" >> "$LOG"
  echo "promotion_bench_failed" > "$DONE"
fi
