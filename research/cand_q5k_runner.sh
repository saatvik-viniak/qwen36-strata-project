#!/bin/bash
# cand_q5k_runner.sh — the Q5_K multi-token kernel candidate chain (SUGGESTIONS.MD S1 /
# PLAN.md #7), under the 30-min-per-bench budget. Waits for cand_uint4.done, then:
#   0. reconcile the tree with the PRIMARY AGENT's verdict (research/uint4_verdict.txt,
#      written after the uint4 cells are harvested: "keep" or "revert"; default revert):
#      cand_runner.sh writes "bench_complete" into cand_uint4.done on ANY completed bench,
#      win or loss, so the done file alone cannot say whether the uint4 patch stays;
#   1. apply_q5k.py (idempotent; the dispatch is STRATA_KQ256-gated = inert default);
#   2. preserve the TRUE CHAMPION (out/strata_byte_loop, NOT out/strata: cand_runner.sh
#      does not restore the champion after a completed bench, so out/strata holds the
#      uint4 candidate binary) -> out/strata_q5k_base, build via build_kit.sh, keep the
#      new binary as out/strata_q5k_cand;
#   3. STOP the server (the parity test allocates a CUDA context beside the champion's
#      ~7.4 GiB - the 8 GiB card must be free), then build the parity test tree
#      (v5: replicating build_kit.sh's toolchain setup - cuda_env.sh + strata_find_cuda,
#      the private cmake if the system's is too old, ccache launchers; the v4 configure
#      failed because cmake could not find nvcc) and run native_expert_parity --synthetic
#      q5_K/q5_K at the model's shapes: bit-for-bit against ggml-cpu's vec_dot for
#      1..8 tokens + the honest 4-token ratio;
#   4. gates: solo old (base binary, no env) vs solo new (kernel binary, STRATA_KQ256=1)
#      vs cmp (bit-identical required);
#   5. bench: candidate 2 cells (serve_262k_q5k.sh: empty + ctx32k, the pool-dot wall
#      where S1 acts; ctx128k is predicted neutral for a CPU-pool kernel and each 128k
#      bench costs ~23 min - it runs in the promotion pass instead), then the champion
#      binary back on out/strata and the control 2 cells (serve_262k.sh); the control
#      doubles as the same-watchdog reference for the confounded uint4 empty/ctx32k
#      cells (the cand_runner bench polled nvidia-smi every 3 s, stealing ~1 core on
#      WSL2; this chain's watchdog polls every 25 s for the same reason);
#   6. leave the champion (base binary) serving; results in research/cand_q5k/.
# Any failure restores the base binary + champion serving before exiting.
# v5 (06:40Z): the parity configure failed in v4 (cmake could not find nvcc) - the step
# now replicates build_kit.sh's toolchain setup (cuda_env.sh + strata_find_cuda + the
# private cmake + ccache) and starts parity_build clean. v4 (06:05Z): the base binary is
# out/strata_byte_loop (cand_runner left the uint4 candidate on out/strata), the final
# restore likewise, the watchdog polls every 25 s. v3 (05:50Z): the reconcile reads
# research/uint4_verdict.txt ("keep"/"revert", default revert) instead of trusting
# cand_uint4.done's "bench_complete" (which a losing bench also writes). v2 (05:25Z)
# moved the parity run after the server stop and made the control pass serve the base
# binary explicitly.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
BASE=http://127.0.0.1:30000
GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf
C=$WS/research/cand_q5k
DONE=$WS/research/cand_q5k.done
LOG=$WS/research/cand_q5k.log
echo "== cand_q5k_runner v5 up $(date -u +%F_%TZ) ==" > "$LOG"

restore_champion () {   # the champion binary back on the port (the champion config)
  bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
  cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata 2>/dev/null \
    || echo "WARN: could not restore the champion binary" >> "$LOG"
  setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
  echo "champion restored $(date -u +%F_%TZ)" >> "$LOG"
}

# 0. wait for the uint4 bench (up to 2.5 h)
for i in $(seq 1 300); do
  [ -f "$WS/research/cand_uint4.done" ] && break
  sleep 30
done
[ -f "$WS/research/cand_uint4.done" ] || { echo "uint4 chain never finished; aborting" >> "$LOG"; exit 1; }
echo "uint4 bench done $(date -u +%F_%TZ)" >> "$LOG"

# 0a. wait for the primary agent's harvested verdict (up to 45 min; default revert)
VERDICT=revert
for i in $(seq 1 90); do
  if [ -f "$WS/research/uint4_verdict.txt" ]; then
    VERDICT=$(cat "$WS/research/uint4_verdict.txt" 2>/dev/null)
    break
  fi
  sleep 30
done
echo "uint4 verdict: $VERDICT $(date -u +%F_%TZ)" >> "$LOG"
mkdir -p "$C"
rm -f "$DONE"

cd /home/dmin/qwen36-strata-project || exit 1

# 0b. reconcile: keep -> the compose build (q5k rides on the uint4 patch); else revert
if [ "$VERDICT" != "keep" ]; then
  python3 "$WS/research/revert_uint4.py" >> "$LOG" 2>&1 || { echo "uint4 revert FAILED" >> "$LOG"; echo "revert_failed" > "$DONE"; exit 1; }
  echo "uint4 patch reverted (kernel-only A/B) $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "uint4 patch KEPT per verdict (the q5k build rides on it) $(date -u +%F_%TZ)" >> "$LOG"
fi

# 1. apply the kernel (idempotent, md5-guarded)
python3 "$WS/research/apply_q5k.py" >> "$LOG" 2>&1 || { echo "apply_q5k FAILED" >> "$LOG"; echo "apply_failed" > "$DONE"; exit 1; }
echo "kernel applied $(date -u +%F_%TZ)" >> "$LOG"

# 2. preserve the TRUE CHAMPION + build
cp /home/dmin/qwen36-strata-project/out/strata_byte_loop /home/dmin/qwen36-strata-project/out/strata_q5k_base \
  || { echo "cannot preserve the champion binary" >> "$LOG"; exit 1; }
echo "base binary preserved (out/strata_q5k_base = strata_byte_loop) $(date -u +%F_%TZ)" >> "$LOG"
if bash build_kit.sh >> "$LOG" 2>&1; then
  echo "build ok $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "BUILD FAILED $(date -u +%F_%TZ)" >> "$LOG"
  echo "build_failed" > "$DONE"
  restore_champion
  exit 1
fi
cp out/strata out/strata_q5k_cand || { echo "cannot keep the candidate binary" >> "$LOG"; exit 1; }

# 3. free the GPU for the parity test's CUDA context, then build + run the parity tree.
# v5: replicate build_kit.sh's toolchain setup (the v4 configure failed without it).
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
echo "server stopped for the parity run $(date -u +%F_%TZ)" >> "$LOG"
CCACHE_ARGS=""
if command -v ccache >/dev/null 2>&1; then
  CCACHE_ARGS="-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_CUDA_COMPILER_LAUNCHER=ccache"
fi
if . ./cuda_env.sh && strata_find_cuda; then
  echo "cuda env ok $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "CUDA ENV FAILED $(date -u +%F_%TZ)" >> "$LOG"
  echo "cuda_env_failed" > "$DONE"
  restore_champion
  exit 1
fi
v="$(cmake --version 2>/dev/null | head -1 | awk '{print $3}')"
if [ -z "$v" ] || [ "$(printf '%s\n3.24\n' "$v" | sort -V | head -1)" != "3.24" ]; then
  if [ -x .toolchain/cmake/bin/cmake ]; then
    PATH="$PWD/.toolchain/cmake/bin:$PATH"; export PATH
    echo "using the private cmake: $(.toolchain/cmake/bin/cmake --version | head -1)" >> "$LOG"
  else
    echo "cmake too old ($v) and no .toolchain/cmake; FAILED" >> "$LOG"
    echo "cmake_missing" > "$DONE"
    restore_champion
    exit 1
  fi
fi
rm -rf parity_build
mkdir -p parity_build
if cmake -G Ninja -S . -B parity_build -DCMAKE_BUILD_TYPE=Release -DSTRATA_ENABLE_CUDA=ON \
     -DSTRATA_BUILD_TESTS=ON -DSTRATA_NATIVE_EXPERTS=ON -DSTRATA_PORTABLE=ON \
     -DSTRATA_Q6K_EXPERTS=ON -DSTRATA_MMQ_KQUANTS=ON -DCMAKE_CUDA_ARCHITECTURES=86-real \
     $CCACHE_ARGS >> "$LOG" 2>&1 \
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

# 5. bench: candidate (STRATA_KQ256=1), then control (the champion binary, no env)
watchdog () {   # $1 = the vram.log file; polls every 25 s (the 3 s poll stole ~1 core on WSL2)
  while true; do
    V=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null)
    [ -n "$V" ] && echo "$(date -u +%F_%TZ) $V" >> "$1"
    if [ -n "$V" ] && [ "$V" -gt 8090 ]; then
      echo "WATCHDOG: $V MiB > 8090" >> "$1"
      pkill -TERM -f 'bench\.py' 2>/dev/null
      break
    fi
    sleep 25
  done
}
run_cells () {   # $1 = serve script, $2 = output dir, $3 = watchdog log
  setsid nohup bash "$1" > /home/dmin/qwen36-strata-project/cand_server.log 2>&1 < /dev/null &
  "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1 || {
    echo "server never healthy ($(date -u +%F_%TZ))" >> "$LOG"; return 1; }
  echo "server healthy $(date -u +%F_%TZ)" >> "$LOG"
  watchdog "$3" & WATCHDOG=$!
  for CELL in empty ctx32k; do
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
# the control pass must serve the champion (base) binary, not the kernel build
cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata
run_cells "$WS/research/serve_262k.sh" "$C/control" "$C/vram_control.log" || { restore_champion; echo "server_failed" > "$DONE"; exit 1; }
echo "control bench complete $(date -u +%F_%TZ)" >> "$LOG"

# 6. leave the champion (base binary) serving
cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata
setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
echo "ok: q5k chain complete $(date -u +%F_%TZ)" >> "$LOG"
echo "bench_complete" > "$DONE"
