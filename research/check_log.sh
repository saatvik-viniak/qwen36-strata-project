#!/bin/bash
# grep engine log for pool decode timings + bench runner status
LOG=/home/dmin/qwen36-strata-project/strata-qwen36.log
echo "=== pool lines in engine log (last 20) ==="
grep -n "CPU pool" "$LOG" | tail -20
echo ""
echo "=== window/hybrid lines (last 10) ==="
grep -n "hybrid experts" "$LOG" | tail -10
echo ""
echo "=== bench runner status ==="
cat "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/bench_runner.log" 2>/dev/null | tail -5 || echo "(no bench log)"
ps aux --width 250 | grep -E 'bench_runner|bench\.py' | grep -v grep || echo "(no bench processes)"
echo ""
echo "=== server health ==="
/opt/strata/venv/bin/python /home/dmin/qwen36-strata-kit/run/wait_health.py http://127.0.0.1:30000/health 3 && echo HEALTHY || echo "NOT-YET"
