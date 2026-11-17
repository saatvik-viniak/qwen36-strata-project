#!/bin/bash
# temp helper: the kq engagement line + the pin lines in both engine logs
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
date -u +%H:%M:%SZ
echo "== the kq engagement line (strata-qwen36.log) =="
grep -n "q5k multi-token kernel" /home/dmin/qwen36-strata-project/strata-qwen36.log 2>/dev/null | tail -3 || echo "(not found)"
echo "== the kq line (cand_server.log) =="
grep -n "q5k multi-token kernel" /home/dmin/qwen36-strata-project/cand_server.log 2>/dev/null | tail -3 || echo "(not found)"
echo "== the pin/arena lines in the current engine log block =="
grep -n "expert arena\|pageable\|cudaHostAlloc\|hybrid experts" /home/dmin/qwen36-strata-project/strata-qwen36.log | tail -6
echo "== the chain log (cell progress) =="
tail -3 "$WS/research/cand_q5k.log"
