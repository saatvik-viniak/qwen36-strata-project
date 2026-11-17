#!/bin/bash
# temp helper: the pool's per-step accounting lines from the engine log
grep -n "pool\|expert kernel\|ms" /home/dmin/qwen36-strata-project/strata-qwen36.log 2>/dev/null | grep -v "q5k multi-token\|pageable\|arena\|staging" | tail -15
echo "== any pool-ms line at all =="
grep -c "pool" /home/dmin/qwen36-strata-project/strata-qwen36.log
