#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== now =="; date -u +%F_%TZ
echo ""
echo "== trial_runner3.log =="
cat "$WS/research/trial_runner3.log" 2>/dev/null || echo "(none)"
echo ""
echo "== trial_server.log tail =="
tail -8 /home/dmin/qwen36-strata-project/trial_server.log 2>/dev/null
echo ""
echo "== processes =="
ps aux --width 250 | grep -E 'serve.server|out/strata|trial_runner|bench.py|cand_runner|wait' | grep -v grep || echo "(none)"
echo ""
echo "== port =="
(exec 3<>/dev/tcp/127.0.0.1/30000) 2>/dev/null && echo PORT_OPEN || echo PORT_CLOSED
echo ""
echo "== live state =="
curl -s -m 4 http://127.0.0.1:30000/metrics 2>/dev/null | head -c 220
echo ""
