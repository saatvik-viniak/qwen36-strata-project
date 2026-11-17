#!/bin/bash
# launch_cand.sh — spawn cand_runner.sh detached (keeps the client alive 4 s).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PIDF=/tmp/cand_runner.pid
setsid nohup bash "$WS/research/cand_runner.sh" > /dev/null 2>&1 < /dev/null &
PID=$!
echo "$PID" > "$PIDF"
sleep 4
if kill -0 "$PID" 2>/dev/null; then
  echo "cand_runner alive (pid $PID)"
else
  echo "cand_runner DIED within 4 s"
fi
