#!/bin/bash
# temp helper: does the committed runner have the CUDA fix? did it relaunch?
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
cd "$WS"
echo "== committed runner (24909d0): parity + cuda lines =="
git show 24909d0:research/cand_q5k_runner.sh | grep -n "cuda_env\|strata_find_cuda\|CMAKE_CUDA_COMPILER\|rm -rf parity_build\|cmake -G" || echo "(no CUDA fix in the committed runner)"
echo "== runner mtime now =="
stat -c "%y" research/cand_q5k_runner.sh
echo "== working-tree runner: same lines =="
grep -n "cuda_env\|strata_find_cuda\|CMAKE_CUDA_COMPILER\|rm -rf parity_build" research/cand_q5k_runner.sh || echo "(none)"
echo "== processes =="
pgrep -af cand_q5k_runner || echo "(no cand_q5k_runner process)"
echo "== log tail =="
tail -3 research/cand_q5k.log
