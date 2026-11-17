#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== NOTEBOOK tail (last row's exact ending) =="
tail -c 1500 "$WS/research/NOTEBOOK.md"
echo ""
echo "== HANDOFF tail =="
tail -30 "$WS/RESEARCH_HANDOFF.md"
echo ""
echo "== SUGGESTIONS demand item locations =="
grep -n "window conflict\|DEMAND\|base leg\|Status:" "$WS/SUGGESTIONS.MD" | tail -25
echo "== SUGGESTIONS tail =="
tail -c 2600 "$WS/SUGGESTIONS.MD"
