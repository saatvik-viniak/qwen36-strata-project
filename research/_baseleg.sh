#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
date -u +%H:%M:%SZ
echo "== the newest research files (the base leg's scripts?) =="
ls -lt --time-style=+%H:%M "$WS/research" | head -8
echo "== any base-leg processes =="
pgrep -af "base|byte_loop|promotion|runner|bench.py" | grep -v pgrep | head -6 || echo "(none)"
echo "== the base leg's log/results? =="
ls "$WS/research" | grep -i base | head -5
tail -4 "$WS/research/promotion_base.log" 2>/dev/null || echo "(no promotion_base.log)"
echo "== the promotion dir's contents (the compose-clean verdict files) =="
ls -l --time-style=+%H:%M "$WS/research/promotion/" 2>/dev/null
