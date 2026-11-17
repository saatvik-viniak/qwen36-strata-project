#!/bin/bash
echo "== parity configure error context =="
grep -n -B6 "PARITY BUILD FAILED" /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/cand_q5k.log | head -40
echo "== cand binaries =="
ls -la --time-style=+%H:%M /home/dmin/qwen36-strata-project/out/strata* 2>/dev/null
echo "== cand_q5k.done =="
cat /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/cand_q5k.done 2>/dev/null
