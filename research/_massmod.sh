#!/bin/bash
# temp helper: the mass-modification event - count + a sample diff
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
cd "$WS"
echo "== the count of changed files =="
git status --short | wc -l
echo "== the breakdown by first token =="
git status --short | awk "{print \$1}" | sort | uniq -c
echo "== sample diff: .dockerignore (first 6 lines) =="
git diff .dockerignore | head -8
echo "== diff stats summary (first lines) =="
git diff --stat | head -6
