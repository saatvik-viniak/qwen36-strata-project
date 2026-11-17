#!/bin/bash
# Compile + run the scratch Q5_K parity test (single-threaded, seconds of CPU).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
OUT=/tmp/q5k_parity
rm -rf "$OUT" && mkdir -p "$OUT"
INC="-I$WS/include -I$WS/src/kernels/cpu -I$WS/third_party/strata-ggml/ggml/src -I$WS/third_party/strata-ggml/ggml/src/ggml-cpu -I$WS/third_party/strata-ggml/ggml/src/ggml-cpu/arch/x86 -I$WS/third_party/strata-ggml/ggml/include"
if g++ -std=c++20 -mavx2 -mfma -mf16c -O2 -o "$OUT/test" "$WS/research/q5k_parity_scratch.cpp" $INC 2>&1 | head -30; then
  [ -f "$OUT/test" ] && nice -n 10 "$OUT/test"
else
  echo "compile failed"
fi
