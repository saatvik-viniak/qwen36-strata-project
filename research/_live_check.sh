#!/bin/bash
# temp helper: live GPU + engine CPU state during the ctx128k decode
nvidia-smi --query-gpu=clocks.sm,clocks.mem,temperature.gpu,power.draw,utilization.gpu,memory.used --format=csv
echo "== engine proc (75789) CPU during decode =="
ps -p 75789 -o pid,pcpu,pmem,etime,stat
echo "== per-core load (top 12, 1 snapshot) =="
ps -e -o pcpu,pid,comm --sort=-pcpu | head -13
