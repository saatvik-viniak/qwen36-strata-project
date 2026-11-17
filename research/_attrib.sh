#!/bin/bash
# temp helper: which commit carries my v6-live edits - attribution check
cd /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== the last 3 commits with times =="
git log -3 --format="%h %ad %s"
echo ""
echo "== e45370b stat =="
git show --stat --format="%h %ad" e45370b | head -12
echo ""
echo "== is my 'THE V6 CHAIN IS LIVE' item in 8691b04 (its diff) or e45370b (mine)? =="
git show 8691b04:SUGGESTIONS.MD | grep -c "THE V6 CHAIN IS LIVE"
git show e45370b:SUGGESTIONS.MD | grep -c "THE V6 CHAIN IS LIVE"
echo "== is lesson #16 in each? =="
git show 8691b04:SUGGESTIONS.MD | grep -c "LESSON #16"
git show e45370b:SUGGESTIONS.MD | grep -c "LESSON #16"
echo "== is handoff #16 in each? =="
git show 8691b04:RESEARCH_HANDOFF.md | grep -c "Continuation #16"
git show e45370b:RESEARCH_HANDOFF.md | grep -c "Continuation #16"
echo "== does 8691b04 contain the primary agent's own annotation style? (sample its SUGGESTIONS diff) =="
git show 8691b04 -- SUGGESTIONS.MD | grep "^+" | grep -v "^+++" | head -6
