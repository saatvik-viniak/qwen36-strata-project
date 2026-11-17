#!/bin/bash
# temp helper: the primary agent's commit 8691b04 - what it committed + the signature
cd /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
git show --stat --format="%h %s | %ad" 8691b04 | head -40
echo "== the committer + the message body tail =="
git log -1 8691b04 --format="%cn <%ce>%n---%n%b" | tail -8
