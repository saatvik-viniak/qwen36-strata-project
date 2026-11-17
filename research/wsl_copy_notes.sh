#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research
mkdir -p "$WS/prior"
cp ~/qwen36-strata-project/.oc/KVNOTE.md "$WS/prior/KVNOTE.md" 2>&1
cp ~/qwen36-strata-project/.oc/Q4KNOTE.md "$WS/prior/Q4KNOTE.md" 2>&1
cp -r ~/qwen36-strata-project/.oc/bench "$WS/prior/bench" 2>&1
echo "copied:"; ls "$WS/prior" | head; ls "$WS/prior/bench" 2>/dev/null | head -20
echo "== any 262k logs? =="
grep -rl "262114\|262144" ~/qwen36-strata-project/.oc --include="*.log" --include="*.md" --include="*.sh" 2>/dev/null | head -10
