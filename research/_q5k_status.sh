#!/bin/bash
# temp helper: q5k chain relaunch status + whether the CUDA fix landed in the runner
echo "== now =="
date -u +"%Y-%m-%d %H:%M:%SZ"
echo "== runner diff: CUDA fix lines =="
cd /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
git diff research/cand_q5k_runner.sh | grep -n -a "cuda_env\|CMAKE_CUDA_COMPILER\|CUDA_HOME" || echo "(no CUDA fix in the diff yet)"
echo "== runner mtime =="
stat -c "%y" research/cand_q5k_runner.sh
echo "== q5k processes =="
pgrep -af cand_q5k_runner || echo "(no cand_q5k_runner process)"
echo "== q5k log tail =="
tail -8 research/cand_q5k.log
