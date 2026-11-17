#!/bin/bash
# temp helper: how build_kit.sh finds the CUDA compiler + where nvcc lives
grep -n "cuda\|CUDA\|nvcc\|CUDACXX" /home/dmin/qwen36-strata-project/build_kit.sh | head -10
echo "== nvcc locations =="
ls /usr/local/cuda*/bin/nvcc 2>/dev/null
which nvcc 2>/dev/null
ls /home/dmin/qwen36-strata-project/parity_build 2>/dev/null | head -4
