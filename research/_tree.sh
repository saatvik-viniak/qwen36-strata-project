#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
date -u +%H:%M:%SZ
echo "== the runner's process tree =="
ps -ef --width 200 | grep -E "cand_q5k_runner|wait_health|serve_262k|out/strata|bench.py" | grep -v grep | head -8
echo ""
echo "== cand_server.log mtime + tail (the control serve's output) =="
stat -c "%y" /home/dmin/qwen36-strata-project/cand_server.log 2>/dev/null
tail -4 /home/dmin/qwen36-strata-project/cand_server.log 2>/dev/null
echo ""
echo "== the chain log's tail (grown past 'candidate bench complete'?) =="
tail -2 "$WS/research/cand_q5k.log"
