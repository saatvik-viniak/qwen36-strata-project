#!/bin/bash
# prefill_rates.sh — compare session prefill lines (baseline vs trial) from the engine log.
L=/home/dmin/qwen36-strata-project/strata-qwen36.log
echo "== ctx32k-sized prompts (31k) =="
grep -E "session 0: prompt 3[0-9],?[0-9]{3} tokens" "$L" | tail -8
echo ""
echo "== ctx128k-sized prompts (12x k) =="
grep -E "session 0: prompt 1[0-9]{2},?[0-9]{3} tokens" "$L" | tail -8
echo ""
echo "== empty prompts (11 tokens) =="
grep -E "session 0: prompt 11 tokens" "$L" | tail -8
