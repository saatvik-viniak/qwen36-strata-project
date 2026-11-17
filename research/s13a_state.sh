#!/bin/sh
# s13a_state.sh — the runner's completion lines + the champion's health + the marker.
tail -4 /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/s13a.log
cat /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/s13a.done 2>/dev/null
curl -s --max-time 5 'http://127.0.0.1:30000/health' || echo "health DOWN"
pgrep -f s13a_runner >/dev/null && echo "runner: alive" || echo "runner: gone"
