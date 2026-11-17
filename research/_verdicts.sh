#!/bin/bash
# temp helper: verdict read - the q5k A/B results, markers, promotion state
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
R="$WS/research"
date -u +%H:%M:%SZ
echo "== git log (last 4) =="
cd "$WS" && git log --oneline -4
echo "== the A/B results (decode_tps per cell) =="
for f in cand/empty.json cand/ctx32k.json control/empty.json control/ctx32k.json; do
  p="$R/cand_q5k/$f"
  if [ -f "$p" ]; then
    t=$(grep -o "\"decode_tps\": [0-9.]*" "$p" | head -1)
    m=$(stat -c "%y" "$p" | cut -d. -f1)
    echo "$f: $t (mtime $m)"
  else
    echo "$f: ABSENT"
  fi
done
echo "== old.json / new.json (the text gates) =="
ls -l --time-style=+%H:%M "$R/cand_q5k/old.json" "$R/cand_q5k/new.json" 2>/dev/null || true
echo "== done markers =="
for f in cand_q5k.done promotion.done; do
  [ -f "$R/$f" ] && echo "$f: $(cat "$R/$f")" || echo "$f: absent"
done
echo "== chain log tail =="
tail -8 "$R/cand_q5k.log"
echo "== promotion log tail =="
tail -6 "$R/promotion.log" 2>/dev/null || echo "(no promotion.log yet)"
echo "== processes =="
pgrep -af "cand_q5k_runner|promotion_pass|bench.py|solo_gate|serve_262k" | grep -v pgrep | head -8 || echo "(none)"
