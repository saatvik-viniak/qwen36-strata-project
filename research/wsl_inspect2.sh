#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
cd ~/qwen36-strata-project || exit 0
git diff > "$WS/research/dirty_wsl_diff.txt" 2>&1
echo "diff saved: $(wc -l < "$WS/research/dirty_wsl_diff.txt") lines"
echo "== kit bench: sampling fields sent? =="
cd ~/qwen36-strata-kit
grep -n -E 'presence_penalty|temperature|sampling|top_p|max_tokens|draft|mtp' run/bench.py 2>/dev/null | head -30
ls run/ 2>&1 | head
echo "== kit.json =="
cat kit.json 2>&1 | head -40
echo "== agent-1-lane state =="
cd ~/agent-1-lane && git log --oneline -3 2>&1 && git status -sb 2>&1 | head -5 && git diff --stat | tail -5
echo "== thermite rigs =="
ls -la ~/.local/share/thermite/rigs/ 2>&1 | head -10
