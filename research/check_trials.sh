#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "=== trial_runner.log ==="
cat "$WS/research/trial_runner.log" 2>/dev/null || echo "(none)"
echo ""
echo "=== done marker ==="
cat "$WS/research/trial_runner.done" 2>/dev/null || echo "(not done)"
echo ""
echo "=== trials dir ==="
find "$WS/research/trials" -name '*.json' -o -name 'vram.log' 2>/dev/null | sort
echo ""
echo "=== runner processes ==="
ps aux --width 200 | grep -E 'trial_runner|bench.py|serve_262k|out/strata' | grep -v grep || echo "(none)"
