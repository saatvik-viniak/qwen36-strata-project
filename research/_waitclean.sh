#!/bin/bash
sleep 420
date -u +%H:%M:%SZ
echo "== the clean-bench results =="
for f in ctx0 ctx32k ctx64k; do
  [ -f "/tmp/clean-$f.json" ] && echo "$f: $(grep -o '"decode_tps": [0-9.]*' /tmp/clean-$f.json | head -1) | prefill $(grep -o '"prefill_tps": [0-9.]*' /tmp/clean-$f.json | head -1)" || echo "$f: (absent)"
done
echo ""
echo "== the clean-bench script's output tail =="
ls -l --time-style=+%H:%M /mnt/c/Users/Admin/AppData/Local/Temp/opencode/ 2>/dev/null | grep -i clean | head -3
echo ""
echo "== the running processes (is the bench still going?) =="
pgrep -af "bench.py|clean_bench|serve.server|out/strata" 2>/dev/null | grep -v pgrep | head -6 || echo "(none)"
