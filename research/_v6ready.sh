#!/bin/bash
# temp helper: v6 readiness - the relink prerequisites (objects + patched sources)
R=/home/dmin/qwen36-strata-project
echo "== the compose objects (the relink's inputs) =="
ls -la --time-style=+%H:%M "$R/out/libstrata_engine.a" "$R/out/libstrata_kernels_cpu.a" 2>/dev/null
echo "== the q5k kernel marker in the source =="
grep -c "q5k_dot" "$R/src/kernels/cpu/kq_avx2.cpp" 2>/dev/null || echo "0"
echo "== the uint4 marker in the engine source =="
grep -c "uint4" "$R/src/qwen35/q36_engine.cu" 2>/dev/null || echo "0"
echo "== the dispatch gate marker =="
grep -c "STRATA_KQ256\|kq256_supported" "$R/src/kernels/cpu/native_expert.cpp" 2>/dev/null || echo "0"
echo "== promotion pass state (one consolidated read) =="
pgrep -af promotion_pass >/dev/null 2>&1 && echo "(pid 91468 alive - settling until 07:27:34Z)" || echo "(promotion pass gone)"
cat /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/promotion.done 2>/dev/null || echo "(no promotion.done yet)"
