#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "=== lean_bench.log ==="
cat "$WS/research/lean_bench.log" 2>/dev/null || echo "(none)"
echo ""
echo "=== pass2 dir ==="
ls -la "$WS/research/baseline/pass2/"
echo ""
echo "=== live state ==="
curl -s -m 4 http://127.0.0.1:30000/metrics | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d.get('live',{}), indent=0)); reqs=d.get('requests',[]); print('last request:', json.dumps(reqs[0] if reqs else {}, indent=0)[:400])" 2>/dev/null || echo "(metrics failed)"
