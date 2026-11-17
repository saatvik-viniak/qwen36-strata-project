#!/bin/bash
# launch_trials3.sh — spawn trial_runner3 detached (keeps the client alive 4 s).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PIDF=/tmp/trial_runner3.pid
setsid nohup bash "$WS/research/trial_runner3.sh" > "$WS/research/trial_runner3.log" 2>&1 < /dev/null &
PID=$!
echo "$PID" > "$PIDF"
sleep 4
if kill -0 "$PID" 2>/dev/null; then
  echo "trial_runner3 alive (pid $PID)"
else
  echo "trial_runner3 DIED within 4 s"
fi
