#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
date -u +%H:%M:%SZ
cd "$WS"
echo "== git log (last 4) =="
git log --oneline -4
echo ""
echo "== the newest research files =="
ls -lt --time-style=+%m-%d_%H:%M "$WS/research" | head -14
echo ""
echo "== running processes =="
pgrep -af "serve.server|out/strata|runner|bench" 2>/dev/null | grep -v pgrep | head -6 || echo "(none)"
echo ""
echo "== the engine log's engine-start lines (last 4) =="
grep -n "engine started" /home/dmin/qwen36-strata-project/strata-qwen36.log | tail -4
echo ""
echo "== the engine log's tail =="
tail -5 /home/dmin/qwen36-strata-project/strata-qwen36.log
echo ""
echo "== any 30001 serve log? =="
ls -lt --time-style=+%m-%d_%H:%M /home/dmin/qwen36-strata-project/*.log /home/dmin/qwen36-strata-project/*.json 2>/dev/null | head -8
echo ""
echo "== the NOTEBOOK's tail (the primary agent's latest rows) =="
tail -3 "$WS/research/NOTEBOOK.md" | cut -c1-400
