#!/bin/bash
# temp helper: final v5 state check (control pass completion)
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== now =="
date -u +%H:%M:%SZ
echo "== log tail =="
tail -3 "$WS/research/cand_q5k.log"
echo "== done file =="
cat "$WS/research/cand_q5k.done" 2>/dev/null || echo "(no done file yet)"
echo "== processes =="
pgrep -af cand_q5k_runner || echo "(chain gone)"
