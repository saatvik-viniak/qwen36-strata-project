#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
cd "$WS"
date -u +%H:%M:%SZ
echo "== git log (last 5) =="
git log --oneline -5
echo ""
echo "== the NOTEBOOK's tail (the primary agent's latest entries) =="
tail -30 "$WS/research/NOTEBOOK.md"
echo ""
echo "== the newest research files =="
ls -lt --time-style=+%H:%M "$WS/research" | head -10
