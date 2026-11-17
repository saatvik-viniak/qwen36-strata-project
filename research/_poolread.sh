#!/bin/bash
P=/home/dmin/qwen36-strata-project/src/kernels/cpu/pool.cpp
echo "== the file size =="
wc -l "$P"
echo "== the key structural sites =="
grep -n "prefetch\|_mm_prefetch\|non_temporal\|ntload\|MADV\|hugepage\|interleav\|locality\|numa\|first_touch\|touch_" "$P" | head -10
echo "== the dot / read loop sites =="
grep -n "for\b.*expert\|dot(\|vec_dot\|weights\|read" "$P" | head -15
echo "== the worker split (what does each worker own?) =="
grep -n "worker\|partition\|chunk\|stride" "$P" | grep -v "^.*//" | head -12
