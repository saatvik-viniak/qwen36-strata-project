#!/bin/bash
# launch_pass2.sh — launcher: starts pass2_runner.sh detached (setsid) so it
# survives Windows-side client exit / agent checkpoints. Returns immediately.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PIDF=/tmp/pass2_runner.pid

if [ -f "$PIDF" ]; then
  OLD=$(cat "$PIDF" 2>/dev/null)
  if kill -0 "$OLD" 2>/dev/null; then
    echo "runner already running (pid $OLD), not starting again"
    exit 0
  fi
fi

setsid nohup bash "$WS/research/pass2_runner.sh" > "$WS/research/pass2_runner.log" 2>&1 < /dev/null &
PID=$!
echo "$PID" > "$PIDF"
echo "launched pass2_runner (pid $PID), detached from this client"
