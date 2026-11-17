#!/bin/bash
# temp helper: warmup timing in the candidate server log + cell timeline
grep -n "warmed up\|ready READY\|loading\|hybrid experts" /home/dmin/qwen36-strata-project/cand_server.log | tail -8
echo "== cand_uint4.log cell lines =="
grep -n "CAND CELL" /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/cand_uint4.log
