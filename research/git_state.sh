#!/bin/bash
# git_state.sh — check the WSL build clone's git state (origin, branch, dirty files).
C=/home/dmin/qwen36-strata-project
cd "$C" || exit 1
echo "== origin =="
git remote -v | head -2
echo ""
echo "== branch/head =="
git status -sb | head -1
git log --oneline -1
echo ""
echo "== dirty files =="
git status --short | head -20
