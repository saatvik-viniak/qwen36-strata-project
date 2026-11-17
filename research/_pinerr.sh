#!/bin/bash
echo "== the pin-failure lines across the compose serves (the pinerr diagnostic's output) =="
grep -n "cudaHostAlloc\|pinerr\|pageable" /home/dmin/qwen36-strata-project/strata-qwen36.log | tail -12
echo ""
echo "== the champion restore block in full (the pinerr line's context) =="
sed -n '716,740p' /home/dmin/qwen36-strata-project/strata-qwen36.log
