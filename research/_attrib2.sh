#!/bin/bash
# temp helper: whose #16 is whose - print the headings + the first line of each section
cd /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== 8691b04 (the primary agent's commit): the #16 heading(s) =="
git show 8691b04:RESEARCH_HANDOFF.md | grep -n -A3 "Continuation #16" | head -12
echo ""
echo "== e45370b (my commit): the #16 heading(s) =="
git show e45370b:RESEARCH_HANDOFF.md | grep -n "Continuation #16" | head -4
echo ""
echo "== 8691b04's SUGGESTIONS.MD: the lesson #16 text (mine or its own?) =="
git show 8691b04:SUGGESTIONS.MD | grep -A2 "LESSON #16" | head -6
echo ""
echo "== e45370b's handoff diff: the first 6 added lines =="
git show e45370b -- RESEARCH_HANDOFF.md | grep "^+" | grep -v "^+++" | head -6
