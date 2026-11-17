#!/bin/bash
# temp helper: nail the candidate-binary overwrite (sizes, mtimes) + the v5 log's apply/build lines
R=/home/dmin/qwen36-strata-project
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== out/ binary sizes + mtimes =="
ls -la --time-style=+%H:%M:%S "$R/out/strata" "$R/out/strata_byte_loop" "$R/out/strata_q5k_base" "$R/out/strata_q5k_cand" 2>/dev/null
echo "== v5 log: the apply + build lines =="
grep -a "cand_q5k_runner v\|verdict\|applied\|kernel\|preserved\|build\|no work\|Configuring done" "$WS/research/cand_q5k.log" | tail -14
echo "== source mtimes (were the q5k-patched files touched at the v5 relaunch?) =="
ls -la --time-style=+%H:%M:%S "$R/src/kernels/cpu/kq_avx2.cpp" "$R/src/kernels/cpu/native_expert.cpp" "$R/src/kernels/native_expert_parity.cpp" 2>/dev/null
