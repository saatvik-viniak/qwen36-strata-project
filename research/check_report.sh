#!/bin/bash
LOG=/home/dmin/qwen36-strata-project/strata-qwen36.log
echo "=== report lines in engine log ==="
grep -n "verify window\|pool multi\|dispatch\|CPU pool call\|accepted per round\|route stats\|routed experts per window" "$LOG" | tail -30
echo ""
echo "=== last 25 log lines ==="
tail -25 "$LOG"
