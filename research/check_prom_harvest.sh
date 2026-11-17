#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== promotion JSONs (compose + base) =="
for f in empty ctx32k ctx128k base_empty base_ctx32k base_ctx128k; do
  p="$WS/research/promotion/$f.json"
  [ -s "$p" ] && echo "$f: $(cat "$p")" || echo "$f: MISSING"
done
echo "== promotion.log tail =="
tail -4 "$WS/research/promotion.log"
echo "== promotion_base.log tail =="
tail -8 "$WS/research/promotion_base.log"
echo "== done markers =="
for f in promotion.done promotion_base.done; do [ -f "$WS/research/$f" ] && echo "$f: $(cat "$WS/research/$f")" || echo "$f: absent"; done
echo "== git state =="
git -C "$WS" log -6 --oneline
echo "== serving state =="
curl -s -m 3 http://127.0.0.1:30000/health && echo || echo "(no server)"
md5sum /home/dmin/qwen36-strata-project/out/strata
