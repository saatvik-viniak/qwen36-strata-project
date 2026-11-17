#!/bin/bash
# kill_trials.sh — stop the trial runner and its children (client-side kills only;
# the server is handled by stop_server.sh separately).
pkill -TERM -f 'trial_runner.sh' 2>/dev/null
pkill -TERM -f 'wait_health.py' 2>/dev/null
pkill -TERM -f 'bench.py' 2>/dev/null
sleep 2
echo "killed trial runner children; server:"
ps aux --width 200 | grep -E 'serve.server|out/strata|trial_runner|wait_health|bench.py' | grep -v grep || echo "(none)"
