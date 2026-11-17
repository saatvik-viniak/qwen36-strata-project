#!/bin/bash
cd ~/qwen36-strata-project || exit 0
echo "== diff stat =="
git diff --stat | head -20
echo "== serve.sh diff =="
git diff serve.sh | head -60
echo "== iq_kernels.cu diff =="
git diff src/kernels/cuda/iq_kernels.cu | head -80
echo "== q36_engine.cu diff (first 120 lines) =="
git diff src/qwen35/q36_engine.cu | head -120
echo "== diff summary =="
git diff | wc -l
