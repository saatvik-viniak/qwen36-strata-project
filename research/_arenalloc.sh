#!/bin/bash
# temp helper: the arena's allocation fallback (the THP lever's site)
R=/home/dmin/qwen36-strata-project
echo "== q36_engine.cu around 3270-3300 (the arena alloc + the swallowed error) =="
sed -n "3270,3300p" "$R/src/qwen35/q36_engine.cu"
