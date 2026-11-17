#!/bin/bash
# cand_q5k_runner.sh — the Q5_K multi-token kernel candidate chain (SUGGESTIONS.MD S1 /
# PLAN.md #7), under the 30-min-per-bench budget. Waits for cand_uint4.done, then:
#   0. reconcile the tree: if the uint4 candidate was REJECTED, revert its patch first
#      (the kernel A/B must be kernel-only);
#   1. apply_q5k.py (idempotent; the dispatch is STRATA_KQ256-gated = inert default);
#   2. preserve out/strata -> out/strata_q5k_base (the A/B's old binary), build via
#      build_kit.sh, keep the new binary as out/strata_q5k_cand;
#   3. STOP the server (the parity test allocates a CUDA context beside the champion's
#      ~7.4 GiB — the 8 GiB card must be free), then build the parity test tree (separate
#      cmake dir, STRATA_BUILD_TESTS=ON) and run native_expert_parity --synthetic
#      q5_K/q5_K at the model's shapes: bit-for-bit against ggml-cpu's vec_dot for
#      1..8 tokens + the honest 4-token ratio;
#   4. gates: solo old (base binary, no env) vs solo new (kernel binary, STRATA_KQ256=1)
#      vs cmp (bit-identical required);
#   5. bench: candidate 3 cells (serve_262k_q5k.sh), then the BASE binary back on
#      out/strata and the control 3 cells (serve_262k.sh);
#   6. leave the champion (base binary) serving; results in research/cand_q5k/.
# Any failure-restores the base binary + champion serving before exiting.
# v2 (05:25Z): the parity run moved AFTER the server stop; the control pass serves the
# base binary explicitly. The v1 process was killed while still in its wait loop.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
BASE=http://127.0.0.1:30000
GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf
C=$WS/research/cand_q5k
DONE=$WS/research/cand_q5k.done
LOG=$WS/research/cand_q5k.log
echo "== cand_q5k_runner v2 up $(date -u +%F_%TZ) ==" > "$LOG"

restore_champion () {   # the base binary back on the port (the champion config)
  bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
  cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata 2>/dev/null \
    || echo "WARN: could not restore the base binary" >> "$LOG"
  setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
  echo "champion restored $(date -u +%F_%TZ)" >> "$LOG"
}

# 0. wait for the uint4 chain (up to 2.5 h)
for i in $(seq 1 300); do
  [ -f "$WS/research/cand_uint4.done" ] && break
  sleep 30
done
[ -f "$WS/research/cand_uint4.done" ] || { echo "uint4 chain never finished; aborting" >> "$LOG"; exit 1; }
VERDICT=$(cat "$WS/research/cand_uint4.done" 2>/dev/null)
echo "uint4 verdict: $VERDICT $(date -u +%F_%TZ)" >> "$LOG"
mkdir -p "$C"
rm -f "$DONE"

cd /home/dmin/qwen36-strata-project || exit 1

# 0b. reconcile: a rejected uint4 must not ride along in the kernel A/B
if [ "$VERDICT" != "bench_complete" ]; then
  python3 "$WS/research/revert_uint4.py" >> "$LOG" 2>&1 || { echo "uint4 revert FAILED" >> "$LOG"; echo "revert_failed" > "$DONE"; exit 1; }
fi

# 1. apply the kernel (idempotent, md5-guarded)
python3 "$WS/research/apply_q5k.py" >> "$LOG" 2>&1 || { echo "apply_q5k FAILED" >> "$LOG"; echo "apply_failed" > "$DONE"; exit 1; }
echo "kernel applied $(date -u +%F_%TZ)" >> "$LOG"

# 2. preserve + build
if [ ! -f out/strata_q5k_base ]; then
  cp out/strata out/strata_q5k_base || { echo "cannot preserve the base binary" >> "$LOG"; exit 1; }
fi
echo "base binary preserved (out/strata_q5k_base) $(date -u +%F_%TZ)" >> "$LOG"
if bash build_kit.sh >> "$LOG" 2>&1; then
  echo "build ok $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "BUILD FAILED $(date -u +%F_%TZ)" >> "$LOG"
  echo "build_failed" > "$DONE"
  restore_champion
  exit 1
fi
cp out/strata out/strata_q5k_cand || { echo "cannot keep the candidate binary" >> "$LOG"; exit 1; }

# 3. free the GPU for the parity test's CUDA context, then build + run the parity tree
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
echo "server stopped for the parity run $(date -u +%F_%TZ)" >> "$LOG"
mkdir -p parity_build
if cmake -G Ninja -S . -B parity_build -DCMAKE_BUILD_TYPE=Release -DSTRATA_ENABLE_CUDA=ON \
     -DSTRATA_BUILD_TESTS=ON -DSTRATA_NATIVE_EXPERTS=ON -DSTRATA_PORTABLE=ON \
     -DSTRATA_Q6K_EXPERTS=ON -DSTRATA_MMQ_KQUANTS=ON -DCMAKE_CUDA_ARCHITECTURES=86-real \
     >> "$LOG" 2>&1 \
  && cmake --build parity_build --target native_expert_parity -j "$(nproc)" >> "$LOG" 2>&1; then
  echo "parity build ok $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "PARITY BUILD FAILED $(date -u +%F_%TZ)" >> "$LOG"
  echo "parity_build_failed" > "$DONE"
  restore_champion
  exit 1
fi
echo "== PARITY RUN q5_K/q5_K $(date -u +%F_%TZ) ==" >> "$LOG"
if Q4KQ_PARITY_EMBD=2048 Q4KQ_PARITY_FF=512 ./parity_build/native_expert_parity --synthetic q5_K/q5_K \
     >> "$LOG" 2>&1; then
  echo "parity ok $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "PARITY FAILED (bit mismatch) $(date -u +%F_%TZ)" >> "$LOG"
  echo "parity_failed" > "$DONE"
  restore_champion
  exit 1
fi

# 4. text gates (the GPU is already free)
FAIL=""
"$PY" tools/qwen35/q36_solo_gate.py --exe /home/dmin/qwen36-strata-project/out/strata_q5k_base \
  --args "--native $GGUF --max-context 32768 --kv int4 --no-graph" --out "$C/old.json" >> "$LOG" 2>&1 \
  && echo "old gate ok $(date -u +%F_%TZ)" >> "$LOG" || { echo "old gate FAILED" >> "$LOG"; FAIL=gate_failed; }
if [ -z "$FAIL" ]; then
  STRATA_KQ256=1 "$PY" tools/qwen35/q36_solo_gate.py --exe /home/dmin/qwen36-strata-project/out/strata \
    --args "--native $GGUF --max-context 32768 --kv int4 --no-graph" --out "$C/new.json" >> "$LOG" 2>&1 \
    && echo "new gate ok (STRATA_KQ256=1) $(date -u +%F_%TZ)" >> "$LOG" || { echo "new gate FAILED" >> "$LOG"; FAIL=gate_failed; }
fi
if [ -z "$FAIL" ]; then
  if "$PY" tools/qwen35/q36_cmp_gate.py "$C/old.json" "$C/new.json" >> "$LOG" 2>&1; then
    echo "cmp gate PASS (bit-identical) $(date -u +%F_%TZ)" >> "$LOG"
  else
    echo "cmp gate DIFFERS $(date -u +%F_%TZ)" >> "$LOG"
    FAIL=gate_differs
  fi
fi
if [ -n "$FAIL" ]; then
  restore_champion
  echo "$FAIL" > "$DONE"
  exit 1
fi

# 5. bench: candidate (STRATA_KQ256=1), then control (the BASE binary, no env)
watchdog () {   # $1 = the vram.log file
  while true; do
    V=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null)
    [ -n "$V" ] && echo "$(date -u +%F_%TZ) $V" >> "$1"
    if [ -n "$V" ] && [ "$V" -gt 8090 ]; then
      echo "WATCHDOG: $V MiB > 8090" >> "$1"
      pkill -TERM -f 'bench\.py' 2>/dev/null
      break
    fi
    sleep 3
  done
}
run_cells () {   # $1 = serve script, $2 = output dir, $3 = watchdog log
  setsid nohup bash "$1" > /home/dmin/qwen36-strata-project/cand_server.log 2>&1 < /dev/null &
  "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1 || {
    echo "server never healthy ($(date -u +%F_%TZ))" >> "$LOG"; return 1; }
  echo "server healthy $(date -u +%F_%TZ)" >> "$LOG"
  watchdog "$3" & WATCHDOG=$!
  for CELL in empty ctx32k ctx128k; do
    case "$CELL" in
      empty)   PT=1 ;;
      ctx32k)  PT=32768 ;;
      ctx128k) PT=131072 ;;
    esac
    echo "== CELL $CELL $(date -u +%F_%TZ) ==" >> "$LOG"
    "$PY" /home/dmin/qwen36-strata-kit/run/bench.py --base-url "$BASE" --model qwen3.6-35b-a3b \
      --prompt-tokens "$PT" --output-tokens 512 --concurrency 1 \
      --out "$2/$CELL.json" >> "$LOG" 2>&1 || echo "bench $CELL FAILED" >> "$LOG"
  done
  kill -TERM $WATCHDOG 2>/dev/null
  bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
  return 0
}

mkdir -p "$C/cand" "$C/control"
run_cells "$WS/research/serve_262k_q5k.sh" "$C/cand" "$C/vram_cand.log" || { restore_champion; echo "server_failed" > "$DONE"; exit 1; }
echo "candidate bench complete $(date -u +%F_%TZ)" >> "$LOG"
# the control pass must serve the BASE binary, not the kernel build
cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata
run_cells "$WS/research/serve_262k.sh" "$C/control" "$C/vram_control.log" || { restore_champion; echo "server_failed" > "$DONE"; exit 1; }
echo "control bench complete $(date -u +%F_%TZ)" >> "$LOG"

# 6. leave the champion (base binary) serving
cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata
setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
echo "ok: q5k chain complete $(date -u +%F_%TZ)" >> "$LOG"
echo "bench_complete" > "$DONE"
