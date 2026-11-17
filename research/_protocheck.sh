#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== serve_262k.sh (full) =="
cat -n "$WS/research/serve_262k.sh"
echo ""
echo "== promotion_pass.sh lines 55-115 (the compose serve + the restore) =="
sed -n '55,115p' "$WS/research/promotion_pass.sh" | cat -n
