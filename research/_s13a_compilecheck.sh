#!/bin/bash
# _s13a_compilecheck.sh — one-shot compile check of the T3 microbench (no GPU,
# no server interaction: safe while any serving/bench runs).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
if gcc -O2 -Wall -pthread -o /tmp/s13a_mb "$WS/research/s13a_microbench.c" 2>/tmp/s13a_cc.log; then
  echo COMPILE_OK
  ls -la /tmp/s13a_mb
  /tmp/s13a_mb 0.03 2>&1 | tail -12   # a tiny-arena smoke run (0.03 GiB = 30 spans fit in RAM; validates the phase machinery end to end)
else
  echo COMPILE_FAILED
  cat /tmp/s13a_cc.log
fi
