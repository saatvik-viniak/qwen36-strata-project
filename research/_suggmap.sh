#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== the S1/S11/S12 status lines + headers =="
grep -n "^## S1 \|^## S11 \|^## S12 \|^## S9 \|^## S2 \|^## S3 \|^\*\*Status" "$WS/SUGGESTIONS.MD" | head -24
echo ""
echo "== the update log's tail (the last committed block header) =="
grep -n "^## Update log\|^### " "$WS/SUGGESTIONS.MD" | tail -8
echo ""
echo "== the file's line count =="
wc -l "$WS/SUGGESTIONS.MD"
