#!/bin/bash
# cand_q5k_runner.sh — the Q5_K multi-token kernel candidate chain (SUGGESTIONS.MD S1 /
# PLAN.md #7), under the 30-min-per-bench budget.
#
# PROMOTION NOTE (2026-11-17 ~11:02Z): the promotion DECIDED — the compose binary
# (out/strata_q5k_cand, md5 8833c30b, q5k+uint4, STRATA_KQ256=1) is the NEW CHAMPION
# CONFIG. Future chains' restore semantics change accordingly: restore = cp
# strata_q5k_cand -> out/strata + serve_262k_q5k.sh (the base binary + serve_262k.sh
# are the CONTROL config). This script's restore_champion() below keeps its historical
# semantics — it is a record of the v6 chain that ran under the old champion.
#
# v6 (2026-11-17 ~07:45Z) — the four fixes from the v5 post-mortem (SUGGESTIONS.MD
# "VOID COMPLETION VERIFIED + THE CONCRETE PATCH SPEC"; the v5 saga: the no-op build
# propagated the champion through cp out/strata -> out/strata_q5k_cand, the gates
# measured byte_loop against itself, and bench.py died on the empty MODEL_PATH in
# every cell while the chain still wrote bench_complete):
#   (1) THE BUILD NO-OP FIX — rm -f out/strata before build_kit.sh. ninja's
#       source-vs-output mtimes cannot see an external overwrite of out/strata (the
#       v4 restore overwrote it with byte_loop), so v5's "build ok (incremental)"
#       relinked nothing; rm'ing the output forces the relink from the 06:16Z compose
#       objects (uint4 in libstrata_engine.a + q5k in libstrata_kernels_cpu.a). The
#       rebuild also recompiles q36_engine.cu + native_expert.cpp (the pinerr
#       diagnostic and the kq engagement log line, both applied after the objects
#       were built).
#   (2) THE TAUTOLOGY GUARD — after the build, cmp -s out/strata out/strata_q5k_base
#       must DIFFER; a silent no-op build is now a loud build_noop failure forever.
#   (3) THE MODEL_PATH FIX — bench.py line 41 reads MODEL_PATH (default ""); v5's
#       four cells died in 3-14 s on HFValidationError(''). The exact proven line
#       from cand_runner.sh (NOT the kit's model.env: that clobbers
#       MAX_CONTEXT/PREFILL/CPU_THREADS for needless risk).
#   (4) THE BENCH-FAILURE FIX — run_cells counts bench failures (a cell passes only
#       if bench.py exits 0 AND its JSON exists with decode_tps) and aborts the
#       chain with a truthful marker (bench_failed / server_failed / build_noop /
#       gate_failed...); "bench_complete" is written ONLY when every cell
#       measured. A lying done-marker poisons every downstream reader.
# v6 also carries: the pinerr diagnostic (q36_engine.cu, applied 06:47Z — one line at
# the cudaHostAlloc fallback, revealing why the 21.14 GiB pool runs in pageable
# memory) and the kq engagement log line (native_expert.cpp — every future A/B's log
# proves which kernel the cells measured).
# Unchanged from v5: the verdict reconcile (research/uint4_verdict.txt, default
# revert), apply_q5k (idempotent), the TRUE CHAMPION preserve (out/strata_byte_loop),
# the parity step's toolchain replication (cuda_env.sh + strata_find_cuda + the
# private cmake + ccache + rm -rf parity_build), the 25 s watchdog (the 3 s poll
# stole ~1 core on WSL2), the 2-cell A/B (empty + ctx32k — the pool-dot wall where
# S1 acts; ctx128k belongs to the promotion pass), the champion restore.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
BASE=http://127.0.0.1:30000
GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf
export MODEL_PATH=/models/qwen36-tokenizer
C=$WS/research/cand_q5k
DONE=$WS/research/cand_q5k.done
LOG=$WS/research/cand_q5k.log
echo "== cand_q5k_runner v6 up $(date -u +%F_%TZ) ==" > "$LOG"

restore_champion () {   # the champion binary back on the port (the champion config)
  bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
  cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata 2>/dev/null \
    || echo "WARN: could not restore the champion binary" >> "$LOG"
  setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
  echo "champion restored $(date -u +%F_%TZ)" >> "$LOG"
}
FAIL_REASON=""

# 0. wait for the uint4 bench (up to 2.5 h; it is DONE — the wait passes instantly)
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

# 2. preserve the TRUE CHAMPION + build (fixes 1 + 2)
cp /home/dmin/qwen36-strata-project/out/strata_byte_loop /home/dmin/qwen36-strata-project/out/strata_q5k_base \
  || { echo "cannot preserve the champion binary" >> "$LOG"; exit 1; }
echo "base binary preserved (out/strata_q5k_base = strata_byte_loop) $(date -u +%F_%TZ)" >> "$LOG"
rm -f /home/dmin/qwen36-strata-project/out/strata
echo "out/strata removed (the no-op-build fix: ninja must relink the compose binary)" >> "$LOG"
if bash build_kit.sh >> "$LOG" 2>&1; then
  echo "build ok $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "BUILD FAILED $(date -u +%F_%TZ)" >> "$LOG"
  echo "build_failed" > "$DONE"
  restore_champion
  exit 1
fi
if cmp -s /home/dmin/qwen36-strata-project/out/strata /home/dmin/qwen36-strata-project/out/strata_q5k_base; then
  echo "BUILD NO-OP: candidate == base — the tautology guard fires $(date -u +%F_%TZ)" >> "$LOG"
  echo "build_noop" > "$DONE"
  restore_champion
  exit 1
fi
echo "candidate binary verified DISTINCT from the base $(date -u +%F_%TZ)" >> "$LOG"
cp out/strata out/strata_q5k_cand || { echo "cannot keep the candidate binary" >> "$LOG"; exit 1; }
echo "candidate binary kept (out/strata_q5k_cand) $(date -u +%F_%TZ)" >> "$LOG"

# 3. free the GPU for the parity test's CUDA context, then build + run the parity tree
# (the toolchain replication: cuda_env.sh + strata_find_cuda + the private cmake + ccache)
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

# 4. text gates (the GPU is already free): solo old (the base binary) vs solo new
# (the COMPOSE binary on out/strata, STRATA_KQ256=1) vs cmp (bit-identical required).
# Fix (2) guarantees the two binaries differ, so the cmp cannot pass tautologically.
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

# 5. bench: candidate (STRATA_KQ256=1), then control (the champion binary, no env).
# Fix (4): a cell passes only if bench.py exits 0 AND its JSON exists with decode_tps;
# any failure aborts the chain with a truthful marker.
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
  CELLFAIL=""
  setsid nohup bash "$1" > /home/dmin/qwen36-strata-project/cand_server.log 2>&1 < /dev/null &
  "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1 || {
    echo "server never healthy ($(date -u +%F_%TZ))" >> "$LOG"; FAIL_REASON=server_failed; return 1; }
  echo "server healthy $(date -u +%F_%TZ)" >> "$LOG"
  watchdog "$3" & WATCHDOG=$!
  for CELL in empty ctx32k; do
    case "$CELL" in
      empty)   PT=1 ;;
      ctx32k)  PT=32768 ;;
    esac
    echo "== CELL $CELL $(date -u +%F_%TZ) ==" >> "$LOG"
    if "$PY" /home/dmin/qwen36-strata-kit/run/bench.py --base-url "$BASE" --model qwen3.6-35b-a3b \
         --prompt-tokens "$PT" --output-tokens 512 --concurrency 1 \
         --out "$2/$CELL.json" >> "$LOG" 2>&1 \
       && [ -s "$2/$CELL.json" ] && grep -q decode_tps "$2/$CELL.json" 2>/dev/null; then
      echo "bench $CELL measured $(date -u +%F_%TZ)" >> "$LOG"
    else
      echo "bench $CELL FAILED" >> "$LOG"; CELLFAIL=1
    fi
  done
  kill -TERM $WATCHDOG 2>/dev/null
  bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1
  if [ -n "$CELLFAIL" ]; then
    FAIL_REASON=bench_failed
    echo "bench failures: the pass aborts (a lying done-marker poisons every reader)" >> "$LOG"
    return 1
  fi
  return 0
}

mkdir -p "$C/cand" "$C/control"
run_cells "$WS/research/serve_262k_q5k.sh" "$C/cand" "$C/vram_cand.log" || { restore_champion; echo "${FAIL_REASON:-server_failed}" > "$DONE"; exit 1; }
echo "candidate bench complete $(date -u +%F_%TZ)" >> "$LOG"
# the control pass must serve the champion (base) binary, not the kernel build
cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata
run_cells "$WS/research/serve_262k.sh" "$C/control" "$C/vram_control.log" || { restore_champion; echo "${FAIL_REASON:-server_failed}" > "$DONE"; exit 1; }
echo "control bench complete $(date -u +%F_%TZ)" >> "$LOG"

# 6. leave the champion (base binary) serving
cp /home/dmin/qwen36-strata-project/out/strata_q5k_base /home/dmin/qwen36-strata-project/out/strata
setsid nohup bash "$WS/research/serve_262k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
echo "ok: q5k chain complete $(date -u +%F_%TZ)" >> "$LOG"
echo "bench_complete" > "$DONE"
