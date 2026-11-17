#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "=== syntax check pass2_runner.sh ==="
bash -n "$WS/research/pass2_runner.sh" && echo SYNTAX_OK || echo SYNTAX_BAD
echo "=== syntax check serve_262k.sh ==="
bash -n "$WS/research/serve_262k.sh" && echo SYNTAX_OK || echo SYNTAX_BAD
echo "=== probe: run runner with a trap to exit after the first lines ==="
timeout 15 bash "$WS/research/pass2_runner.sh" 2>&1 | head -40
echo "=== probe exit: $? ==="
