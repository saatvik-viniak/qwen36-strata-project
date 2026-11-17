#!/bin/bash
# check_soon2.sh — wait N seconds (arg, default 300), then report the trial verdicts.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
sleep "${1:-300}"
bash "$WS/research/check_verdicts.sh"
