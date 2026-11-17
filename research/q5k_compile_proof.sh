#!/bin/bash
# Scratch compile-proof for the Q5_K multi-token kernel (kq_avx2.cpp + dispatch).
# Compiles the PATCHED Windows-checkout sources with the same -mavx2 -mfma the
# build gives kq_avx2.cpp, against the repo's include paths. No GPU, no build
# tree, no out/strata: a syntax/type proof only.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
OUT=/tmp/q5k_proof
rm -rf "$OUT" && mkdir -p "$OUT"
FLAGS="-std=c++20 -mavx2 -mfma -O2 -fsyntax-only -Wall -Wno-unused-function"
INC="-I$WS/include -I$WS/third_party/strata-ggml/ggml/src -I$WS/third_party/strata-ggml/ggml/src/ggml-cpu -I$WS/third_party/strata-ggml/ggml/src/ggml-cpu/arch/x86 -I$WS/third_party/strata-ggml/ggml/include"
echo "== kq_avx2.cpp =="
g++ $FLAGS $INC "$WS/src/kernels/cpu/kq_avx2.cpp" 2>&1 | head -40 || true
echo "== native_expert.cpp =="
g++ $FLAGS $INC -DGGML_BACKEND_LL -DSTRATA_NATIVE_EXPERTS "$WS/src/kernels/cpu/native_expert.cpp" 2>&1 | head -60 || true
echo "== done (empty output above = clean) =="
