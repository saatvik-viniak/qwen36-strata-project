#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
grep -n "^## " "$WS/SUGGESTIONS.MD" | tail -10
