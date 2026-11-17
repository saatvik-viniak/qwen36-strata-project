#!/bin/bash
# temp helper: does the engine log record the KQ256 dispatch state? (false-cell evidence)
L=/home/dmin/qwen36-strata-project/strata-qwen36.log
echo "== engine log: KQ256/kq256/dispatch lines (last 6) =="
grep -a -i "kq256\|dispatch\|STRATA_" "$L" 2>/dev/null | tail -6 || echo "(no dispatch lines found)"
echo "== engine log tail (the false empty cell's load lines) =="
tail -4 "$L" 2>/dev/null
