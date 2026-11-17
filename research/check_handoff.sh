#!/bin/bash
F=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/RESEARCH_HANDOFF.md
wc -l "$F"
grep -n "Continuation #" "$F" | tail -5
