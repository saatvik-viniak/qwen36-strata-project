#!/bin/bash
cd /home/dmin/qwen36-strata-project || exit 1
echo "== the pool's warning site (the source file) =="
grep -rn "strata cpu pool" src/ include/ 2>/dev/null | head -5
echo "== pool step-path candidates =="
grep -rn "pool" src/qwen35/q36_engine.cu 2>/dev/null | grep -i -E "run|dispatch|step|launch|worker|thread" | head -12
echo "== native_expert.cpp: the worker/thread entry =="
grep -n "worker\|thread\|pool" src/kernels/cpu/native_expert.cpp 2>/dev/null | head -20
