#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
sleep 90
echo "now: $(date -u +%F_%TZ)"
echo "== s12c.log =="
cat "$WS/research/s12c.log" 2>/dev/null || echo "(absent)"
echo "== processes =="
ps aux --width 250 | grep -E "s12c_runner|serve.sh|out/strata" | grep -v grep || echo "(none)"
