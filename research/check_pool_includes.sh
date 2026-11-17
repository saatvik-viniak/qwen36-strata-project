#!/bin/bash
cd /home/dmin/qwen36-strata-project || exit 1
echo "== getenv/cstdlib in pool.cpp =="
grep -n "getenv\|<cstdlib>\|<cstdio>" src/kernels/cpu/pool.cpp | head -6
echo "== the includes block =="
sed -n '1,30p' src/kernels/cpu/pool.cpp | grep -n "#include" 
echo "== call-site context (q36_engine.cu 2560-2575) =="
sed -n '2560,2575p' src/qwen35/q36_engine.cu
