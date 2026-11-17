#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== void markers before =="
for f in cand_q5k.done promotion.done; do [ -f "$WS/research/$f" ] && echo "$f: $(cat "$WS/research/$f")" || echo "$f: absent"; done
# both markers are VOID (the v5 chain and the v1 promotion pass benched NOTHING —
# bench.py died on the empty MODEL_PATH; the markers must never lie → delete, and
# v6/v2 write their own truthful markers)
rm -f "$WS/research/cand_q5k.done" "$WS/research/promotion.done"
# keep the v1 promotion log as the forensic record of the void completion, but kill
# its trigger surface (v2 truncates it at start)
[ -f "$WS/research/promotion.log" ] && mv "$WS/research/promotion.log" "$WS/research/promotion_v1_void.log" && echo "promotion.log -> promotion_v1_void.log (forensics kept)"
rm -rf "$WS/research/promotion" 2>/dev/null && echo "empty promotion/ dir removed"
echo "== void markers after =="
for f in cand_q5k.done promotion.done; do [ -f "$WS/research/$f" ] && echo "$f: still present" || echo "$f: deleted"; done
