#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
sed -n '1255,1300p' "$WS/SUGGESTIONS.MD" | cat -A | sed -n '1,46p' | cut -c1-100
