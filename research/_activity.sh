#!/bin/bash
# temp helper: any primary-agent activity? (runner mtime, log tails, git status)
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== now =="
date -u +%H:%M:%SZ
echo "== runner mtime =="
stat -c "%y" "$WS/research/cand_q5k_runner.sh"
echo "== git status (short) =="
cd "$WS" && git status --short | head -6
echo "== q5k log tail =="
tail -2 "$WS/research/cand_q5k.log"
echo "== any new chain processes? =="
pgrep -af "cand_q5k_runner|promotion_pass|bench.py" || echo "(none)"
