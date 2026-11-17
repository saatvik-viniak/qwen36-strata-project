#!/bin/bash
echo "=== THP settings ==="
cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || echo "(no THP knob)"
cat /sys/kernel/mm/transparent_hugepage/hugepages-2048kB/state 2>/dev/null
echo ""
echo "=== mem policy / numa ==="
cat /proc/vmstat 2>/dev/null | grep -E 'thp|huge' | head -5
echo ""
echo "=== CPU info ==="
lscpu | grep -E 'Model name|Cache|MHz' | head -6
echo ""
echo "=== RAM size ==="
free -g | head -2
echo ""
echo "=== bench status ==="
tail -3 "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/bench_runner.log" 2>/dev/null
ls -la "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/baseline/pass2/" 2>/dev/null | tail -2
