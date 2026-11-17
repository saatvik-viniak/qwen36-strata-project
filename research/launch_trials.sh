#!/bin/bash
# launch_trials.sh — spawn trial_runner detached (keeps the client alive 4 s).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PIDF=/tmp/trial_runner.pid

if [ -f "$PIDF" ]; then
  OLD=$(cat "$PIDF" 2>/dev/null)
  if kill -0 "$OLD" 2>/dev/null; then
    echo "trial runner already running (pid $OLD)"
    exit 0
  fi
fi

setsid nohup bash "$WS/research/trial_runner.sh" nommq ct5 mtp3 > "$WS/research/trial_runner.log" 2>&1 < /dev/null &
PID=$!
echo "$PID" > "$PIDF"
sleep 4
if kill -0 "$PID" 2>/dev/null; then
  echo "trial runner started (pid $PID) and alive after 4 s"
else
  echo "trial runner DIED within 4 s"
fi
