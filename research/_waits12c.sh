#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
sleep 1500
date -u +%H:%M:%SZ
echo "== git log (last 3) =="
cd "$WS" && git log --oneline -3
echo ""
echo "== the s12c dir + log =="
ls -l --time-style=+%H:%M "$WS/research/s12c/" 2>/dev/null | head -8
cat "$WS/research/s12c.log" 2>/dev/null | tail -12
echo ""
echo "== the engine log's newest blocks (the S12-C serves' empty rounds) =="
grep -n "engine started\|q5k multi-token kernel\|CPU expert workers are configured" /home/dmin/qwen36-strata-project/strata-qwen36.log | tail -10
echo ""
grep -o "prompt 11 tokens = 0 reused + 11 read in [0-9]* ms ([0-9.]* tok/s), 512 generated in [0-9]* ms ([0-9.]* tok/s)" /home/dmin/qwen36-strata-project/strata-qwen36.log | tail -8
