#!/bin/bash
# launch_watcher.sh — spawn watch_and_swap.sh detached (keeps the client alive 4 s).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PIDF=/tmp/watch_swap.pid
setsid nohup bash "$WS/research/watch_and_swap.sh" > /dev/null 2>&1 < /dev/null &
PID=$!
echo "$PID" > "$PIDF"
sleep 4
if kill -0 "$PID" 2>/dev/null; then
  echo "watcher alive (pid $PID)"
else
  echo "watcher DIED within 4 s"
fi
