#!/bin/bash
# launch_bench.sh — spawn bench_runner detached, then KEEP THE CLIENT ALIVE 4 s
# so the detached runner fully starts (proven survival pattern). Returns after.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PIDF=/tmp/bench_runner.pid

if [ -f "$PIDF" ]; then
  OLD=$(cat "$PIDF" 2>/dev/null)
  if kill -0 "$OLD" 2>/dev/null; then
    echo "bench runner already running (pid $OLD)"
    exit 0
  fi
fi

setsid nohup bash "$WS/research/bench_runner.sh" > "$WS/research/bench_runner.log" 2>&1 < /dev/null &
PID=$!
echo "$PID" > "$PIDF"
sleep 4
if kill -0 "$PID" 2>/dev/null; then
  echo "bench runner started (pid $PID) and alive after 4 s"
else
  echo "bench runner DIED within 4 s"
fi
