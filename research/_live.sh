#!/bin/bash
# temp helper: lean live-state check (no git status - it hung on the big index)
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
date -u +%H:%M:%SZ
echo "== chain processes =="
pgrep -af "cand_q5k_runner|promotion_pass|bench.py|ninja|cmake|strata" | grep -v pgrep | head -8 || echo "(none)"
echo "== cand_q5k.log tail =="
tail -6 "$WS/research/cand_q5k.log"
echo "== the actual MODEL_PATH export in promotion_pass.sh =="
grep -n "export MODEL_PATH" "$WS/research/promotion_pass.sh"
echo "== apply_q5k.py mtime (was the table updated?) =="
stat -c "%y" "$WS/research/apply_q5k.py"
