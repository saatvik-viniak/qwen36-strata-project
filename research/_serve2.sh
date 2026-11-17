#!/bin/bash
# temp helper: the cand pass's server log - the pin line, the kq engagement line, cell progress
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
R="$WS/research"
date -u +%H:%M:%SZ
echo "== cand_server.log (the CURRENT pass's engine output): the load + pin + kq lines =="
grep -E "engine started|expert arena|pageable|pinned|q5k multi-token|context 262144" /home/dmin/qwen36-strata-project/cand_server.log 2>/dev/null | tail -8
echo ""
echo "== the verdict files =="
for f in cand/empty.json cand/ctx32k.json control/empty.json control/ctx32k.json; do
  p="$R/cand_q5k/$f"
  [ -f "$p" ] && echo "$f: $(grep -o "\"decode_tps\": [0-9.]*" "$p" | head -1)" || echo "$f: absent"
done
tail -4 "$R/cand_q5k.log"
echo "== markers: =="
[ -f "$R/cand_q5k.done" ] && cat "$R/cand_q5k.done" || echo "(chain still running)"
