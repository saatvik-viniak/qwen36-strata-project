#!/bin/bash
# watch_and_swap.sh — wait for nommq/ctx32k to resolve, then swap runners.
# Rationale (user rule 2026-11-17: no benchmark expected > 30 min): the old runner's
# next cell is nommq/ctx128k (~65 min at the native-kernel prefill) — over budget.
# Triggers (either):
#   1. trials/nommq/ctx32k.json appears  -> the cell measured; kill the runner before
#      it starts (or just after it started) the ctx128k bench;
#   2. trial_runner.log shows "CELL ctx128k" under nommq -> the ctx32k bench FAILED
#      and the runner is burning the over-budget cell; kill immediately.
# Then spawn trial_runner2 (ct5 + mtp3, all cells fit the budget).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
LOG=$WS/research/watch_swap.log
RLOG=$WS/research/trial_runner.log
echo "watcher up $(date -u +%F_%TZ)" > "$LOG"
for i in $(seq 1 240); do   # up to 20 min
  if [ -f "$WS/research/trials/nommq/ctx32k.json" ]; then
    echo "ctx32k landed $(date -u +%F_%TZ); letting bench.py exit fully (4 s)" >> "$LOG"
    sleep 4
    pkill -TERM -f 'trial_runner\.sh' 2>/dev/null
    sleep 1
    pkill -TERM -f 'bench\.py' 2>/dev/null
    sleep 2
    echo "old runner killed; spawning trial_runner2 $(date -u +%F_%TZ)" >> "$LOG"
  elif grep -q "TRIAL nommq CELL ctx128k" "$RLOG" 2>/dev/null; then
    echo "ctx128k started WITHOUT a ctx32k result (bench failed); killing old runner $(date -u +%F_%TZ)" >> "$LOG"
    pkill -TERM -f 'trial_runner\.sh' 2>/dev/null
    sleep 1
    pkill -TERM -f 'bench\.py' 2>/dev/null
    sleep 2
    echo "old runner killed; spawning trial_runner2 $(date -u +%F_%TZ)" >> "$LOG"
  else
    sleep 5
    continue
  fi
  setsid nohup bash "$WS/research/trial_runner2.sh" > "$WS/research/trial_runner2.log" 2>&1 < /dev/null &
  sleep 4
  echo "trial_runner2 spawned (pid $(pgrep -f 'trial_runner2\.sh' | head -1)) $(date -u +%F_%TZ)" >> "$LOG"
  exit 0
done
echo "gave up waiting after 20 min $(date -u +%F_%TZ)" >> "$LOG"
exit 1
