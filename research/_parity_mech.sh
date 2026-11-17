#!/bin/bash
# temp helper: parity-failure mechanism + surviving artifacts after the q5k chain v4 death
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
R=/home/dmin/qwen36-strata-project
echo "== out/ artifacts =="
ls -la --time-style=+%H:%M "$R/out/" | grep -a "strata" || echo "(no out listing)"
echo "== md5: is out/strata the byte-loop champion? =="
md5sum "$R/out/strata" "$R/out/strata_byte_loop" "$R/out/strata_q5k_cand" 2>/dev/null || true
echo "== the CUDA toolchain hook =="
grep -n "strata_cuda_toolchain" "$R/CMakeLists.txt" | head -4
echo "== cuda.cmake around line 29 =="
sed -n "20,36p" "$R/cmake/backends/cuda.cmake"
echo "== runner mtime (has the primary agent edited since 06:09?) =="
stat -c "%y" "$WS/research/cand_q5k_runner.sh"
echo "== cand_q5k.done? (the stale failure marker) =="
cat "$WS/research/cand_q5k.done" 2>/dev/null || echo "(no done file)"
