#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== the serve scripts' pool-workers flag =="
grep -n "pool-workers\|POOL_WORKERS\|cpu-threads\|CPU_THREADS" "$WS/research/serve_262k.sh" "$WS/research/serve_262k_q5k.sh" 2>/dev/null | head -6
echo ""
echo "== bench.py: the warmup / two-session structure =="
grep -n "warm\|session\|requests\|range\|sleep" /home/dmin/qwen36-strata-kit/run/bench.py 2>/dev/null | head -12
echo ""
echo "== the control pass's live state (the load started?) =="
tail -3 "$WS/research/cand_q5k.log"
pgrep -af "serve_262k|strata_q5k_base" | grep -v pgrep | head -3 || echo "(the control server not up yet)"
