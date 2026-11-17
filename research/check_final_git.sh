#!/bin/bash
cd /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project || exit 1
echo "== promoted ledger in HEAD =="
git show HEAD:research/hillclimb/ledger.jsonl | wc -l
git show HEAD:research/hillclimb/ledger.jsonl | grep -o '"run": "promotion-[a-z-]*"' | tail -2
echo "== last commits =="
git log --oneline -3
