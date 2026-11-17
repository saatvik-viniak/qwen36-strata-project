#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "=== now ==="
date -u +%F_%TZ
echo ""
echo "=== trial server log ==="
tail -20 /home/dmin/qwen36-strata-project/trial_server.log 2>/dev/null || echo "(none)"
echo ""
echo "=== engine log tail ==="
tail -8 /home/dmin/qwen36-strata-project/strata-qwen36.log 2>/dev/null
echo ""
echo "=== port ==="
(exec 3<>/dev/tcp/127.0.0.1/30000 && echo OPEN && exec 3>&-) 2>/dev/null || echo CLOSED
echo ""
echo "=== engine processes ==="
ps aux --width 250 | grep -E 'strata' | grep -v grep | head -4
echo ""
echo "=== live state ==="
curl -s -m 4 http://127.0.0.1:30000/metrics 2>/dev/null | head -c 300
echo ""
echo "=== trials dir ==="
ls -la "$WS/research/trials/" "$WS/research/trials/"*/ 2>/dev/null
