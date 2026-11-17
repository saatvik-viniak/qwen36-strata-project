#!/bin/bash
echo "=== /health ==="
curl -s -m 5 http://127.0.0.1:30000/health | head -c 300; echo
echo "=== /stats ==="
curl -s -m 5 http://127.0.0.1:30000/stats | head -c 2000; echo
echo "=== /metrics ==="
curl -s -m 5 http://127.0.0.1:30000/metrics | head -c 2000; echo
echo "=== / ==="
curl -s -m 5 http://127.0.0.1:30000/ | head -c 500; echo
