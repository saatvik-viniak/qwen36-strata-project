#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "now: $(date -u +%F_%TZ)"
echo "== s12c final state =="
cat "$WS/research/s12c.done" 2>/dev/null || echo "(no marker)"
tail -4 "$WS/research/s12c.log"
echo "== server =="
curl -s -m 3 http://127.0.0.1:30000/health && echo || echo "(no server)"
md5sum /home/dmin/qwen36-strata-project/out/strata
echo "== PROGRESS.md =="
F="$WS/PROGRESS.md"
[ -f "$F" ] && wc -l "$F" && tail -25 "$F" || echo "(absent)"
echo "== git status (mine) =="
git -C "$WS" log -3 --oneline
