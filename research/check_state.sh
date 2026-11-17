#!/bin/bash
# Deep state check
echo "=== ALL WSL PROCESSES ==="
ps aux --width 200 | grep -v 'ps aux' | grep -v grep || echo "(none)"
echo ""
echo "=== PORT 30000 ==="
(exec 3<>/dev/tcp/127.0.0.1/30000 && echo "PORT 30000 OPEN" && exec 3>&-) 2>/dev/null || echo "PORT 30000 CLOSED"
echo ""
echo "=== kit run dir ==="
ls -lat ~/qwen36-strata-kit/run/ 2>/dev/null | head -30
echo ""
echo "=== find recent json anywhere in kit ==="
find ~/qwen36-strata-kit -name '*.json' -mmin -600 2>/dev/null | head -20
echo ""
echo "=== find recent json in home ==="
find ~ -maxdepth 4 -name '*.json' -mmin -600 2>/dev/null | grep -v '.git' | head -20
echo ""
echo "=== engine log tail ==="
tail -15 ~/qwen36-strata-project/strata-qwen36.log 2>/dev/null
