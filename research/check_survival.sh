#!/bin/bash
echo "=== is the server from the probe alive? ==="
ps aux --width 250 | grep -E 'strata|serve' | grep -v grep || echo "(none)"
echo ""
(exec 3<>/dev/tcp/127.0.0.1/30000 && echo "PORT OPEN" && exec 3>&-) 2>/dev/null || echo "PORT CLOSED"
echo ""
tail -3 /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>/dev/null || echo "(no serve log)"
