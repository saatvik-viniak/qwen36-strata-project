#!/bin/bash
# temp helper: promotion pass live state
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== now =="
date -u +%H:%M:%SZ
echo "== promotion processes =="
pgrep -af promotion_pass || echo "(promotion_pass not running)"
echo "== promotion.log =="
cat "$WS/research/promotion.log" 2>/dev/null || echo "(no log yet)"
echo "== promotion.done =="
cat "$WS/research/promotion.done" 2>/dev/null || echo "(no done file)"
echo "== promotion/ dir =="
ls -la "$WS/research/promotion/" 2>/dev/null || echo "(no dir)"
