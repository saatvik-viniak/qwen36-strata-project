#!/bin/bash
# temp helper: the .gitattributes diff (the flip source?) + the primary agent's new check scripts
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
cd "$WS"
echo "== .gitattributes diff (first 12 lines) =="
git diff .gitattributes | head -14
echo ""
echo "== a .cpp spot check: q36_engine.cu content identical modulo CR? =="
git show HEAD:src/qwen35/q36_engine.cu | tr -d '\r' > /tmp/h_cu.txt
tr -d '\r' < src/qwen35/q36_engine.cu > /tmp/w_cu.txt
cmp -s /tmp/h_cu.txt /tmp/w_cu.txt && echo "IDENTICAL (line endings only)" || echo "CONTENT DIFFERS"
echo ""
echo "== the primary agent's new check scripts (mtimes) =="
ls -la --time-style=+%H:%M research/check_bench_env.sh research/check_bench_fail.sh research/check_binaries.sh research/check_promo_state.sh research/check_q5k_cells.sh research/check_q5k_gate.sh research/check_q5k_gate2.sh research/kill_v1.sh 2>/dev/null
