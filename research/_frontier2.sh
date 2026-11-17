#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
date -u +%H:%M:%SZ
cd "$WS"
echo "== git log (last 4) =="
git log --oneline -4
echo ""
echo "== the newest research files =="
ls -lt --time-style=+%m-%d_%H:%M "$WS/research" | head -12
echo ""
echo "== running processes (runners/servers) =="
pgrep -af "runner|serve_262k|bench.py|promotion|s12|strata" 2>/dev/null | grep -v pgrep | head -8 || echo "(none)"
echo ""
echo "== the engine log's newest engine-start + tail =="
grep -n "engine started" /home/dmin/qwen36-strata-project/strata-qwen36.log | tail -3
tail -3 /home/dmin/qwen36-strata-project/strata-qwen36.log
echo ""
echo "== the NOTEBOOK's tail (the primary agent's latest) =="
tail -6 "$WS/research/NOTEBOOK.md"
