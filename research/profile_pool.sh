#!/bin/bash
# profile_pool.sh — §9.0 CPU-side profiling of the pool during a live decode.
# Usage (run while the server decodes a long request): bash profile_pool.sh [seconds]
# Requires perf (check paranoid level first). Never run while a bench is timing.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
OUT=$WS/research/profile
mkdir -p "$OUT"
SECS=${1:-30}
PID=$(pgrep -f 'out/strata --serve' | head -1)
[ -z "$PID" ] && { echo "no engine process"; exit 1; }
echo "profiling engine pid $PID for ${SECS}s"
cat /proc/sys/kernel/perf_event_paranoid
perf stat -p "$PID" -e cycles,instructions,cache-misses,cache-references -- sleep "$SECS" 2>&1 | tail -20
perf record -g -p "$PID" -o "$OUT/perf.data" -- sleep "$SECS" 2>&1 | tail -3
perf report -i "$OUT/perf.data" --stdio --no-children 2>/dev/null | head -60 > "$OUT/perf_report.txt"
head -50 "$OUT/perf_report.txt"
