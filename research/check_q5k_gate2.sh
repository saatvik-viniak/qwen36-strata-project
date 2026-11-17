#!/bin/bash
grep -a "gate ok\|gate FAILED\|cmp gate\|CELL\|bench complete\|parity\|verdict" /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/cand_q5k.log | tail -12
echo "now: $(date -u +%F_%TZ)"
