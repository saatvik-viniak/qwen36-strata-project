#!/bin/bash
# temp helper: is the mass modification a CRLF flip? are the shell scripts affected?
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
cd "$WS"
echo "== how many of the modified are shell scripts in research/? =="
git status --short | grep -c "research/.*\.sh"
echo "== is cand_q5k_runner.sh among them? =="
git status --short | grep "cand_q5k_runner.sh" || echo "(not listed as modified)"
echo "== the runner: working-tree line endings =="
file research/cand_q5k_runner.sh
grep -c $'\r' research/cand_q5k_runner.sh 2>/dev/null || echo "0 CR chars"
echo "== the runner: content diff vs HEAD ignoring CR (numstat after tr) =="
git show HEAD:research/cand_q5k_runner.sh | tr -d '\r' > /tmp/head_runner.sh
tr -d '\r' < research/cand_q5k_runner.sh > /tmp/wt_runner.sh
cmp -s /tmp/head_runner.sh /tmp/wt_runner.sh && echo "CONTENT IDENTICAL (only line endings differ)" || echo "CONTENT DIFFERS"
echo "== .dockerignore: same check =="
git show HEAD:.dockerignore | tr -d '\r' > /tmp/head_docker.sh
tr -d '\r' < .dockerignore > /tmp/wt_docker.sh
cmp -s /tmp/head_docker.sh /tmp/wt_docker.sh && echo "CONTENT IDENTICAL (only line endings differ)" || echo "CONTENT DIFFERS"
echo "== my SUGGESTIONS.MD =="
file SUGGESTIONS.MD
