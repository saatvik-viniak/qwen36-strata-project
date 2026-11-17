#!/bin/bash
sleep 240
date -u +%H:%M:%SZ
echo "== the clean baseline's results (complete?) =="
for f in ctx0 ctx32k ctx64k; do
  [ -f "/tmp/clean-$f.json" ] && echo "$f: $(grep -o '"decode_tps": [0-9.]*' /tmp/clean-$f.json | head -1) | prefill $(grep -o '"prefill_tps": [0-9.]*' /tmp/clean-$f.json 2>/dev/null | head -1)" || echo "$f: (absent)"
done
echo ""
echo "== the clean bench's process state =="
pgrep -af "bench.py|clean_bench" 2>/dev/null | grep -v pgrep | head -3 || echo "(the bench script exited - the results are final)"
echo ""
echo "== the clean engine log's session lines (the per-cell engine-side reads) =="
grep "session 0" /tmp/clean-q36.log 2>/dev/null | tail -8
