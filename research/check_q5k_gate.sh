#!/bin/bash
echo "now: $(date -u +%F_%TZ)"
tail -20 /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/cand_q5k.log | grep -v "^p[0-9]" | tail -12
