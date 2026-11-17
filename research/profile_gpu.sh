#!/bin/bash
# profile_gpu.sh — §9.0 GPU-side profiling of the int4 attention during a 128k decode.
# nsys capture on the engine, then ncu on the top kernels. Never run while a bench times.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
OUT=$WS/research/profile
mkdir -p "$OUT"
PID=$(pgrep -f 'out/strata --serve' | head -1)
[ -z "$PID" ] && { echo "no engine process"; exit 1; }
NSYS=/usr/local/bin/nsys
NCU=/usr/local/cuda-12.6/bin/ncu
"$NSYS" profile -o "$OUT/engine_nsys" -p "$PID" --duration 30 --capture-range none 2>&1 | tail -5
"$NSYS" stats --report cudagpukernsum --format csv "$OUT/engine_nsys.nsysrep" > "$OUT/kernel_sum.csv" 2>/dev/null
head -25 "$OUT/kernel_sum.csv"
echo "--- ncu (top kernels, 10 s) ---"
"$NCU" --target-processes all -p "$PID" -c 30 -o "$OUT/engine_ncu" 2>&1 | tail -5
