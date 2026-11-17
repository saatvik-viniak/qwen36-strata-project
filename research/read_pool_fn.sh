#!/bin/bash
cd /home/dmin/qwen36-strata-project || exit 1
echo "== run_split_multi_native + the slot stride =="
sed -n '1365,1440p' src/kernels/cpu/pool.cpp
echo "== ExpertJobMulti struct =="
grep -n "struct ExpertJobMulti" -A 14 include/strata/kernels/cpu/pool.hpp src/kernels/cpu/pool.cpp 2>/dev/null | head -30
