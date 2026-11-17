#!/bin/sh
# status_now.sh — one line each: UTC clock, pass2b runner alive?, its log tail.
date -u +%H:%M:%SZ
pgrep -f q4ks_pass2b_bench.sh >/dev/null && echo "pass2b runner: alive" || echo "pass2b runner: gone"
tail -3 /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/q4ks_pass2b.log
