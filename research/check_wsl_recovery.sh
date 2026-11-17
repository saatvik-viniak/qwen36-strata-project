#!/bin/bash
echo "now: $(date -u +%F_%TZ)"
echo "== engines =="
ps aux --width 250 | grep "out/strata" | grep -v grep | head -4 || echo "(no engine)"
echo "== port 30000 =="
curl -s -m 3 http://127.0.0.1:30000/health && echo || echo "(no server on 30000)"
echo "== port 30001 =="
curl -s -m 3 http://127.0.0.1:30001/health && echo || echo "(no server on 30001)"
echo "== binaries =="
cd /home/dmin/qwen36-strata-project/out && md5sum strata strata_q5k_cand 2>/dev/null
