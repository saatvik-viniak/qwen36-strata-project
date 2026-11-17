#!/bin/bash
cd /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project || exit 1
echo "== last commits =="
git log -4 --oneline
echo "== what 2de129a touched =="
git show 2de129a --stat --oneline | head -12
echo "== status =="
git status --short
