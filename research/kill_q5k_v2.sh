#!/bin/bash
pkill -9 -f cand_q5k_runner.sh 2>/dev/null
sleep 2
if ps aux --width 250 | grep -v grep | grep -q cand_q5k_runner; then
  echo "STILL_ALIVE:"
  ps aux --width 250 | grep cand_q5k_runner | grep -v grep
else
  echo "GONE"
fi
