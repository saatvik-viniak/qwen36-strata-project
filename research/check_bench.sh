#!/bin/bash
echo "=== bench_runner.log tail ==="
tail -12 "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/bench_runner.log" 2>/dev/null
echo ""
echo "=== done marker ==="
cat "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/bench_runner.done" 2>/dev/null || echo "(not done)"
echo ""
echo "=== pass2/pass3 JSONs so far ==="
ls -la "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/baseline/pass2/" 2>/dev/null
ls -la "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/baseline/pass3/" 2>/dev/null
