#!/bin/bash
# cand_runner.sh — uint4-attention candidate verification, per INT4-KV-PROMPT.md's gates,
# under the 30-min-per-bench budget. Waits for trial_runner2.done, then: preserve the old
# binary, build, STOP the champion server (VRAM must be free for the VERIFY/gates),
# VERIFY=1, the solo/cmp gates, then the 3-cell bench on the candidate. Any verification
# failure restarts the champion before exiting. Results in research/cand_uint4/.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
KIT=/home/dmin/qwen36-strata-kit
PY=/opt/strata/venv/bin/python
export MODEL_PATH=/models/qwen36-tokenizer
BASE=http://127.0.0.1:30000
GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf
C=$WS/research/cand_uint4
DONE=$WS/research/cand_uint4.done
LOG=$WS/research/cand_uint4.log
echo "== cand_runner up $(date -u +%F_%TZ) ==" > "$LOG"

restore_champion () {   # the byte-loop binary back on the port (the champion config)
  bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
  cp /home/dmin/qwen36-strata-project/out/strata_byte_loop /home/dmin/qwen36-strata-project/out/strata 2>/dev/null \
    || echo "WARN: could not restore the byte-loop binary" >> "$LOG"
  setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
  echo "champion restored $(date -u +%F_%TZ)" >> "$LOG"
}

# wait for the remaining trials to finish (up to 2 h; trial_runner3.done)
for i in $(seq 1 240); do
  [ -f "$WS/research/trial_runner3.done" ] && break
  sleep 30
done
[ -f "$WS/research/trial_runner3.done" ] || { echo "trials never finished; aborting" >> "$LOG"; exit 1; }
echo "trials done $(date -u +%F_%TZ)" >> "$LOG"
mkdir -p "$C"
rm -f "$DONE"

cd /home/dmin/qwen36-strata-project || exit 1

# 1. preserve the byte-loop binary (the gates compare against it)
if [ ! -f out/strata_byte_loop ]; then
  cp out/strata out/strata_byte_loop || { echo "cannot preserve the old binary" >> "$LOG"; exit 1; }
fi
echo "old binary preserved (out/strata_byte_loop) $(date -u +%F_%TZ)" >> "$LOG"

# 2. build (only q36_engine.cu changed; ninja rebuilds that + links)
if bash build_kit.sh >> "$LOG" 2>&1; then
  echo "build ok $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "BUILD FAILED $(date -u +%F_%TZ)" >> "$LOG"
  echo "build_failed" > "$DONE"
  exit 1
fi

# 3. free the GPU: the VERIFY and gates need the VRAM (the champion holds ~7.4 GiB)
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
echo "champion stopped for the verification $(date -u +%F_%TZ)" >> "$LOG"

# 4. the engine's own VERIFY gates (old kernel beside new, bit for bit)
FAIL=""
if STRATA_Q36_VERIFY=1 ./out/strata --native "$GGUF" --max-context 32768 --kv int4 --no-graph \
     --tokens 1,2,3,4,5,6,7,8 --n 16 >> "$LOG" 2>&1 && ! grep -q "VERIFY MISMATCH" "$LOG"; then
  echo "verify run ok, 0 mismatches $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "VERIFY FAILED (mismatches or run error) $(date -u +%F_%TZ)" >> "$LOG"
  FAIL=verify_failed
fi

# 5. text parity gates: the byte-loop binary vs the uint4 binary, greedy, bit for bit
if [ -z "$FAIL" ]; then
  "$PY" tools/qwen35/q36_solo_gate.py --exe /home/dmin/qwen36-strata-project/out/strata_byte_loop \
    --args "--native $GGUF --max-context 32768 --kv int4 --no-graph" --out "$C/old.json" >> "$LOG" 2>&1 \
    && echo "old gate ok $(date -u +%F_%TZ)" >> "$LOG" || { echo "old gate FAILED" >> "$LOG"; FAIL=gate_failed; }
fi
if [ -z "$FAIL" ]; then
  "$PY" tools/qwen35/q36_solo_gate.py --exe /home/dmin/qwen36-strata-project/out/strata \
    --args "--native $GGUF --max-context 32768 --kv int4 --no-graph" --out "$C/new.json" >> "$LOG" 2>&1 \
    && echo "new gate ok $(date -u +%F_%TZ)" >> "$LOG" || { echo "new gate FAILED" >> "$LOG"; FAIL=gate_failed; }
fi
if [ -z "$FAIL" ]; then
  if "$PY" tools/qwen35/q36_cmp_gate.py "$C/old.json" "$C/new.json" >> "$LOG" 2>&1; then
    echo "cmp gate PASS (bit-identical) $(date -u +%F_%TZ)" >> "$LOG"
  else
    echo "cmp gate DIFFERS $(date -u +%F_%TZ)" >> "$LOG"
    FAIL=gate_differs
  fi
fi

# any verification failure: restore the champion and stop
if [ -n "$FAIL" ]; then
  restore_champion
  echo "$FAIL" > "$DONE"
  exit 1
fi

# 6. the 3-cell bench on the candidate (champion config; serve_262k.sh stops any server)
setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/cand_server.log 2>&1 < /dev/null &
if "$PY" "$KIT/run/wait_health.py" "$BASE/health" 900; then
  echo "candidate server healthy $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "candidate server never healthy" >> "$LOG"; restore_champion; echo "server_failed" > "$DONE"; exit 1
fi
( while true; do
    V=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null)
    [ -n "$V" ] && echo "$(date -u +%F_%TZ) $V" >> "$C/vram.log"
    if [ -n "$V" ] && [ "$V" -gt 8090 ]; then
      echo "WATCHDOG: $V MiB > 8090" >> "$C/vram.log"
      pkill -TERM -f 'bench\.py' 2>/dev/null
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
  echo "== CAND CELL $CELL $(date -u +%F_%TZ) ==" >> "$LOG"
  "$PY" "$KIT/run/bench.py" --base-url "$BASE" --model qwen3.6-35b-a3b \
    --prompt-tokens "$PT" --output-tokens 512 --concurrency 1 \
    --out "$C/$CELL.json" >> "$LOG" 2>&1 || echo "bench $CELL FAILED" >> "$LOG"
done
kill -TERM $WATCHDOG 2>/dev/null
echo "ok: candidate bench complete $(date -u +%F_%TZ)" >> "$LOG"
echo "bench_complete" > "$DONE"
