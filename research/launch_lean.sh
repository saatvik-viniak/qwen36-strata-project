#!/bin/bash
# launch_lean.sh — stop the old bench runner + its bench.py children (client-side
# only; the server stays), then spawn lean_bench128k detached and keep this
# client alive 4 s (proven survival pattern).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PIDF=/tmp/lean_bench.pid

OLD=$(cat /tmp/bench_runner.pid 2>/dev/null)
if [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null; then
  echo "killing old bench runner (pid $OLD)"
  kill -TERM "$OLD" 2>/dev/null
fi
pkill -TERM -f 'bench.py' 2>/dev/null
sleep 5

setsid nohup bash "$WS/research/lean_bench128k.sh" > "$WS/research/lean_bench.log" 2>&1 < /dev/null &
PID=$!
echo "$PID" > "$PIDF"
sleep 4
if kill -0 "$PID" 2>/dev/null; then
  echo "lean bench runner started (pid $PID) and alive after 4 s"
else
  echo "lean bench runner DIED within 4 s"
fi
