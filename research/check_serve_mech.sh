#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== serve.sh: how CPU_THREADS reaches the engine =="
grep -n "CPU_THREADS\|pool-workers\|pool_workers" /home/dmin/qwen36-strata-project/serve.sh 2>/dev/null | head -8 || echo "(no match in serve.sh)"
echo "== engine log: the worker warning + per-load worker lines =="
grep -n "worker" /home/dmin/qwen36-strata-project/strata-qwen36.log 2>/dev/null | tail -6
echo "== THP state (check_thp.sh, reused) =="
bash "$WS/research/check_thp.sh" 2>/dev/null | head -12
echo "== free =="
free -m | head -3
echo "== engine log size =="
wc -l /home/dmin/qwen36-strata-project/strata-qwen36.log 2>/dev/null
