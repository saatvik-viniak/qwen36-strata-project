#!/bin/bash
cd /home/dmin/qwen36-strata-project || exit 1
grep -n "run_split_multi_native" src/kernels/cpu/pool.cpp src/qwen35/q36_engine.cu include/strata/kernels/cpu/*.hpp 2>/dev/null
