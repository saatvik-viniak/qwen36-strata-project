#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== now =="; date -u +%F_%TZ
echo ""
echo "== trial server log tail (reading progress) =="
tail -6 /home/dmin/qwen36-strata-project/trial_server.log 2>/dev/null
echo ""
echo "== trials dir =="
ls -la "$WS/research/trials/"*/ 2>/dev/null
echo ""
echo "== engine log trial sessions =="
grep -E "session 0: prompt" /home/dmin/qwen36-strata-project/strata-qwen36.log | tail -3
