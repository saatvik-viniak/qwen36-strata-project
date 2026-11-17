#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
cd "$WS"
echo "== git status: SUGGESTIONS.MD modified? =="
git status --short | grep -E "SUGGESTIONS|NOTEBOOK|promotion" | head -5
echo "== the S1/S12 Status lines as they stand now =="
grep -n "^## S1 \|^\*\*Status" SUGGESTIONS.MD | head -16
echo ""
echo "== the NOTEBOOK's new lines (1ab1b07) =="
git show 1ab1b07 -- research/NOTEBOOK.md | grep "^+" | grep -v "^+++" | head -4
echo ""
echo "== the promotion pass's remaining flow (its ctx128k cell running) =="
tail -3 "$WS/research/promotion.log"
