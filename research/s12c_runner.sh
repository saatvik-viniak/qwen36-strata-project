#!/bin/bash
# s12c_runner.sh — S12 lever C: the worker-count test (config-only, SUGGESTIONS.MD S12).
# The engine warns at every load (log lines 614..672): "8 CPU expert workers are
# configured, but this CPU has 6 physical cores ... Recommended: --pool-workers 5".
# Three configs (5/6/12), one load + one empty cell each, on the CHAMPION compose
# binary (STRATA_KQ256=1), the promotion protocol per config: stop -> serve ->
# wait health -> settle 900 s -> bench empty (512 tok, greedy, concurrency 1).
# The w=8 anchor is REUSED: the promotion compose-clean empty 22.53 tok/s
# (09:27:18Z, same binary, same protocol, same day). Results: research/s12c/
# {w5,w6,w12}.json + the per-config engine-log slice (the worker line proves the
# config engaged). The comparison is the SCREEN: a config winning >= +3% over the
# w=8 anchor justifies a confirm pass; a full promotion pass (3 cells) decides
# any config change. Leaves the CHAMPION config serving (compose, w=8).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
BASE=http://127.0.0.1:30000
DONE=$WS/research/s12c.done
LOG=$WS/research/s12c.log
OUT=$WS/research/s12c
ENGINE_LOG=/home/dmin/qwen36-strata-project/strata-qwen36.log
export MODEL_PATH=/models/qwen36-tokenizer
FAIL=0
echo "== s12c_runner up $(date -u +%F_%TZ) ==" > "$LOG"
mkdir -p "$OUT"
rm -f "$DONE"

# the champion binary on out/strata (stop first: the base champion serves now)
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
cp /home/dmin/qwen36-strata-project/out/strata_q5k_cand /home/dmin/qwen36-strata-project/out/strata \
  || { echo "cp FAILED" >> "$LOG"; echo "aborted" > "$DONE"; exit 1; }
md5sum /home/dmin/qwen36-strata-project/out/strata >> "$LOG"

for W in 5 6 12; do
  bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
  BEFORE=$(wc -l < "$ENGINE_LOG" 2>/dev/null)
  [ -z "$BEFORE" ] && BEFORE=0
  echo "== config w=$W serve $(date -u +%F_%TZ) (engine log line $BEFORE) ==" >> "$LOG"
  CPU_THREADS=$W setsid nohup bash "$WS/research/serve_262k_q5k_w.sh" \
    > /home/dmin/qwen36-strata-project/s12c_serve_w$W.log 2>&1 < /dev/null &
  if "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1; then
    echo "w=$W server healthy $(date -u +%F_%TZ)" >> "$LOG"
  else
    echo "w=$W server never healthy" >> "$LOG"; FAIL=1
    continue
  fi
  echo "w=$W settling 900 s $(date -u +%F_%TZ)" >> "$LOG"
  sleep 900
  echo "w=$W settle done $(date -u +%F_%TZ)" >> "$LOG"
  echo "== w=$W CELL empty $(date -u +%F_%TZ) ==" >> "$LOG"
  if "$PY" /home/dmin/qwen36-strata-kit/run/bench.py --base-url "$BASE" --model qwen3.6-35b-a3b \
       --prompt-tokens 1 --output-tokens 512 --concurrency 1 \
       --out "$OUT/w$W.json" >> "$LOG" 2>&1 \
     && [ -s "$OUT/w$W.json" ] && grep -q decode_tps "$OUT/w$W.json" 2>/dev/null; then
    echo "bench w=$W measured $(date -u +%F_%TZ)" >> "$LOG"
  else
    echo "bench w=$W FAILED" >> "$LOG"; FAIL=1
  fi
  tail -n +$((BEFORE + 1)) "$ENGINE_LOG" > "$OUT/engine_w$W.log" 2>/dev/null
  grep -m1 "worker" "$OUT/engine_w$W.log" >> "$LOG" 2>&1 || echo "(no worker line in the w=$W slice)" >> "$LOG"
done

# leave the CHAMPION config serving (the compose binary, w=8 = the script's default)
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
setsid nohup bash "$WS/research/serve_262k_q5k_w.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
if "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1; then
  echo "champion restored (compose, w=8 default) healthy $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "champion serve never healthy — THE BOX IS NOT SERVING; restore by hand" >> "$LOG"
  FAIL=1
fi
if [ "$FAIL" -eq 0 ]; then
  echo "ok: s12c complete $(date -u +%F_%TZ)" >> "$LOG"
  echo "bench_complete" > "$DONE"
else
  echo "s12c completed WITH failures — the marker never lies $(date -u +%F_%TZ)" >> "$LOG"
  echo "bench_failed" > "$DONE"
fi
