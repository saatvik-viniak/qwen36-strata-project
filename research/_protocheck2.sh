#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== strata-qwen36.log lines 630-712 (the serve blocks) =="
sed -n '630,712p' /home/dmin/qwen36-strata-project/strata-qwen36.log | cat -n
echo ""
echo "== serve.sh (the tree's launcher) =="
cat -n /home/dmin/qwen36-strata-project/serve.sh 2>/dev/null | head -40
