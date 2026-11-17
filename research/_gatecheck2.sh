#!/bin/bash
echo "== strata-qwen36.log: kq/q5k/STRATA lines with line numbers =="
grep -n "KQ256\|q5k\|multi-token\|STRATA_\|pool-workers\|expert worker" /home/dmin/qwen36-strata-project/strata-qwen36.log | tail -12
echo ""
echo "== the log's tail (the current/base serve) =="
tail -4 /home/dmin/qwen36-strata-project/strata-qwen36.log
