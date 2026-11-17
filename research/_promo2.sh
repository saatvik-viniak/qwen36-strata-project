#!/bin/bash
# temp helper: lockstep md5s + compile-safety of the kqlog lambda + promotion fixes
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== md5s: WSL tree vs Windows tree (native_expert.cpp lockstep) =="
md5sum /home/dmin/qwen36-strata-project/src/kernels/cpu/native_expert.cpp
md5sum "$WS/src/kernels/cpu/native_expert.cpp"
echo "== the other three patched files vs apply_q5k's table =="
echo "kq_avx2.cpp (WSL): $(md5sum /home/dmin/qwen36-strata-project/src/kernels/cpu/kq_avx2.cpp | cut -d' ' -f1) (table patched: f1984db86e7ed2c442629c985f29a48b)"
echo "parity.cpp  (WSL): $(md5sum /home/dmin/qwen36-strata-project/src/kernels/native_expert_parity.cpp | cut -d' ' -f1) (table patched: e9843fc079c8b921567131f2d56c31e6)"
echo "kq_avx2.hpp (WSL): $(md5sum /home/dmin/qwen36-strata-project/include/strata/kernels/cpu/kq_avx2.hpp | cut -d' ' -f1) (table patched: 660af9f8b041c55b96cf2777672c2d92)"
echo "== kqlog compile safety: the include + the full lambda =="
grep -n "#include <cstdio>\|#include <stdio.h>" /home/dmin/qwen36-strata-project/src/kernels/cpu/native_expert.cpp | head -2
grep -n -A7 "static const bool kq = \[\] { const char\* v = std::getenv" /home/dmin/qwen36-strata-project/src/kernels/cpu/native_expert.cpp | head -10
echo "== promotion_pass.sh: the four spec'd fixes present? =="
grep -n "MODEL_PATH" "$WS/research/promotion_pass.sh" | head -3
grep -n "empty.json\|cand/\|control/" "$WS/research/promotion_pass.sh" | head -5
grep -n "cmp -s\|md5sum" "$WS/research/promotion_pass.sh" | head -3
grep -n "bench_failed\|fail" "$WS/research/promotion_pass.sh" | head -4
echo "== promotion trigger condition =="
grep -n "cand_q5k.done\|trigger\|until\|sleep" "$WS/research/promotion_pass.sh" | head -6
