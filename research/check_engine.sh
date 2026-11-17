#!/bin/bash
LOG=/home/dmin/qwen36-strata-project/strata-qwen36.log
echo "=== engine log last 12 lines ==="
tail -12 "$LOG"
echo ""
echo "=== session lines so far (count) ==="
grep -c "session" "$LOG"
echo ""
echo "=== hybrid experts lines count ==="
grep -c "hybrid experts" "$LOG"
echo ""
echo "=== nvidia-smi (from WSL) ==="
/usr/bin/wslpath -w /dev/null >/dev/null 2>&1 || true
if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader; else echo "(no nvidia-smi in WSL)"; fi
echo ""
echo "=== bench processes ==="
ps aux --width 200 | grep bench.py | grep -v grep | head -2
