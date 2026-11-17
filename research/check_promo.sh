#!/bin/bash
sleep 3
echo "== promotion log =="
cat /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/promotion.log
echo "== q5k gate progress =="
tail -3 /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/cand_q5k.log
