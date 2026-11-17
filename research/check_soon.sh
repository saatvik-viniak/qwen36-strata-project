#!/bin/bash
# check_soon.sh — wait N seconds (arg, default 210), then run the trial-server check.
# Needed because cmd mangles nested quotes on `wsl bash -c "sleep && ..."`.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
sleep "${1:-210}"
bash "$WS/research/check_trialserver.sh"
