#!/bin/bash
sleep 420
grep -a "CELL\|healthy\|gate ok\|cmp gate\|complete" /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/cand_q5k.log | tail -8
echo "now: $(date -u +%F_%TZ)"
