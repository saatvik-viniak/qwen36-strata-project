#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== now =="; date -u +%F_%TZ
echo ""
echo "== trial_runner2.log (full) =="
cat "$WS/research/trial_runner2.log" 2>/dev/null || echo "(none)"
echo ""
echo "== watch_swap.log =="
cat "$WS/research/watch_swap.log" 2>/dev/null
echo ""
echo "== trial_server.log tail =="
tail -12 /home/dmin/qwen36-strata-project/trial_server.log 2>/dev/null
echo ""
echo "== all strata processes =="
ps aux --width 250 | grep -E 'serve.server|out/strata|trial_runner|bench.py|watch_and_swap|cand_runner' | grep -v grep || echo "(none)"
echo ""
echo "== port =="
(exec 3<>/dev/tcp/127.0.0.1/30000) 2>/dev/null && echo PORT_OPEN || echo PORT_CLOSED
echo ""
echo "== done markers =="
ls -la "$WS/research/trial_runner2.done" 2>/dev/null || echo "trial_runner2.done MISSING"
