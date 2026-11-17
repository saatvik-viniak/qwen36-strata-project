#!/bin/bash
date -u +%H:%M:%SZ
echo "== the processes now (the 30001 server's state after the clean bench's exit) =="
pgrep -af "serve.server|out/strata|clean_bench|bench.py" 2>/dev/null | grep -v pgrep | head -6 || echo "(none)"
echo ""
echo "== port 30000/30001 health =="
curl -s -m 3 http://127.0.0.1:30000/health | head -c 200; echo
curl -s -m 3 http://127.0.0.1:30001/health | head -c 200; echo
