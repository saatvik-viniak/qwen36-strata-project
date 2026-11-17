#!/bin/bash
grep -n "MODEL_PATH\|model_path" /home/dmin/qwen36-strata-kit/run/bench.py | head -8
echo "== promotion pass state =="
ps aux --width 250 | grep -E "promotion_pass|cand_q5k_runner" | grep -v grep
