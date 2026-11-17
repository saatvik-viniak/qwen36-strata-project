#!/bin/bash
# clone_diffs.sh — show the WSL clone's local source edits (vs its HEAD).
C=/home/dmin/qwen36-strata-project
cd "$C" || exit 1
echo "== serve.sh diff =="
git diff serve.sh | head -30
echo ""
echo "== iq_kernels.cu diff (stat + first lines) =="
git diff --stat src/kernels/cuda/iq_kernels.cu
git diff src/kernels/cuda/iq_kernels.cu | head -40
echo ""
echo "== q36_engine.cu diff (stat + first lines) =="
git diff --stat src/qwen35/q36_engine.cu
git diff src/qwen35/q36_engine.cu | head -60
