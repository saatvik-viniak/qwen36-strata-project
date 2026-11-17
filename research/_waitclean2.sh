#!/bin/bash
sleep 300
date -u +%H:%M:%SZ
echo "== the clean baseline's results =="
for f in ctx0 ctx32k ctx64k; do
  [ -f "/tmp/clean-$f.json" ] && echo "$f: $(grep -o '"decode_tps": [0-9.]*' /tmp/clean-$f.json | head -1) | prefill $(grep -o '"prefill_tps": [0-9.]*' /tmp/clean-$f.json | head -1) | peak $(grep -o '"peak_gib": [0-9.]*' /tmp/clean-$f.json | head -1)" || echo "$f: (absent)"
done
echo ""
echo "== the clean engine log's load block (the slot count!) =="
grep -n "engine started\|hybrid experts\|cudaHostAlloc\|CPU expert workers\|warmed up" /tmp/clean-q36.log 2>/dev/null | head -10
echo ""
echo "== the processes (the bench state) =="
pgrep -af "bench.py|clean_bench" 2>/dev/null | grep -v pgrep | head -4 || echo "(bench done)"
