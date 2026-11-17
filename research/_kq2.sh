#!/bin/bash
echo "== the kq lines in the engine log (both passes' states) =="
grep -n "q5k multi-token kernel" /home/dmin/qwen36-strata-project/strata-qwen36.log | tail -4
