#!/bin/bash
echo "=== runner processes ==="
ps aux --width 250 | grep -E 'pass2_runner|serve_262k|serve\.sh|strata' | grep -v grep
echo ""
echo "=== runner log ==="
cat "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/pass2_runner.log" 2>/dev/null || echo "(no log yet)"
echo ""
echo "=== serve launch log ==="
tail -5 /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>/dev/null
echo ""
echo "=== port 30000 ==="
(exec 3<>/dev/tcp/127.0.0.1/30000 && echo OPEN && exec 3>&-) 2>/dev/null || echo CLOSED
echo ""
echo "=== done marker ==="
cat "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/pass2_runner.done" 2>/dev/null || echo "(not done yet)"
