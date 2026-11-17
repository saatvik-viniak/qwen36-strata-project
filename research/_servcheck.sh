#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== diff serve_262k.sh vs serve_262k_q5k.sh =="
diff "$WS/research/serve_262k.sh" "$WS/research/serve_262k_q5k.sh" && echo "(identical)"
echo ""
echo "== the promotion log's serve/health/settle lines =="
head -12 "$WS/research/promotion.log"
echo ""
echo "== which serve script the promotion pass used =="
grep -n "serve_262k" "$WS/research/promotion_pass.sh" 2>/dev/null || ls "$WS/research" | grep -i "promo"
