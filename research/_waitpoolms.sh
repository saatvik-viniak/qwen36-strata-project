#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
D=$WS/research/poolms.done
date -u +%H:%M:%SZ
for i in $(seq 1 32); do
  [ -f "$D" ] && break
  sleep 45
done
date -u +%H:%M:%SZ
echo "== poolms.done =="
[ -f "$D" ] && cat "$D" || echo "(absent after the wait)"
echo ""
echo "== poolms.log tail (12) =="
tail -12 "$WS/research/poolms.log" 2>/dev/null
echo ""
echo "== poolms/empty.json =="
[ -s "$WS/research/poolms/empty.json" ] && grep -o '"decode_tps": [0-9.]*\|"decode_ms": [0-9.]*\|"warmup": \[\|"ttft_ms": [0-9.]*' "$WS/research/poolms/empty.json" | head -6 || echo "(absent)"
echo ""
if [ -f "$D" ] && grep -q "bench_complete\|bench_failed" "$D" 2>/dev/null; then
  echo "== analyze_poolms.sh (read-only compute) =="
  bash "$WS/research/analyze_poolms.sh" 2>&1 | head -40
else
  echo "(capture not complete - no analysis yet)"
fi
