#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "now: $(date -u +%F_%TZ)"
echo "== processes =="
ps aux --width 250 | grep -E "promotion_pass|wait_health|serve_262k|bench\.py|strata" | grep -v grep || echo "(none)"
echo "== promotion.log =="
cat "$WS/research/promotion.log" 2>/dev/null || echo "(absent)"
echo "== done files =="
for f in cand_q5k.done promotion.done; do
  if [ -f "$WS/research/$f" ]; then echo "$f: $(cat "$WS/research/$f")"; else echo "$f: absent"; fi
done
echo "== md5 (WSL clone out/) =="
cd /home/dmin/qwen36-strata-project/out 2>/dev/null && md5sum strata strata_q5k_cand strata_q5k_base strata_byte_loop 2>/dev/null || echo "(no out/)"
echo "== health =="
curl -s -m 3 http://127.0.0.1:30000/health && echo || echo "(no server on 30000)"
