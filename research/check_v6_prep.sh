#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
cd /home/dmin/qwen36-strata-project || exit 1
echo "== STRATA_KQ256 sites =="
grep -n "STRATA_KQ256\|kq256_supported" src/kernels/cpu/native_expert.cpp src/kernels/cpu/kq_avx2.cpp src/qwen35/q36_engine.cu 2>/dev/null | head -20
echo "== q36_engine.cu fprintf include check (the pinerr edit must compile) =="
grep -n "#include <cstdio>\|#include <stdio.h>\|std::fprintf\|fprintf(" src/qwen35/q36_engine.cu | head -8
echo "== verdict + done files =="
for f in cand_uint4.done uint4_verdict.txt cand_q5k.done promotion.done; do
  p="$WS/research/$f"
  [ -f "$p" ] && echo "$f: $(cat "$p")" || echo "$f: absent"
done
echo "== the A/B results dirs (v6 trigger inputs) =="
ls -l "$WS/research/cand_q5k/cand/" "$WS/research/cand_q5k/control/" 2>/dev/null || echo "(absent)"
echo "== serve scripts differ ONLY by STRATA_KQ256? =="
diff "$WS/research/serve_262k.sh" "$WS/research/serve_262k_q5k.sh" | head -12
echo "== server state =="
curl -s -m 3 http://127.0.0.1:30000/health && echo || echo "(no server)"
md5sum /home/dmin/qwen36-strata-project/out/strata
