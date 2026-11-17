#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "=== lean log ==="
cat "$WS/research/lean_bench.log"
echo ""
echo "=== pass2 ctx128k decode_tps ==="
/opt/strata/venv/bin/python -c "import json; d = json.load(open('$WS/research/baseline/pass2/ctx128k.json')); print(d['decode_tps'], d['prefill_tps'], d['ttft_ms'], d['peak_gib'])"
echo ""
echo "=== done marker ==="
cat "$WS/research/lean_bench.done" 2>/dev/null || echo "(not done)"
