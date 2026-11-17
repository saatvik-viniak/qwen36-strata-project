#!/bin/bash
# temp helper: hexdump lines 216-219 of SUGGESTIONS.MD
sed -n "216,219p" /mnt/c/Users/placeholder 2>/dev/null
sed -n "216,219p" "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/SUGGESTIONS.MD" | cat -A
