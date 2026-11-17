#!/bin/bash
# temp helper: the v5 bench section in full - what did bench.py do for 16 s?
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== cand_q5k.log: everything after the cmp gate =="
sed -n "/cmp gate PASS/,\$p" "$WS/research/cand_q5k.log"
echo ""
echo "== vram_cand.log (watchdog polls + any WATCHDOG line) =="
tail -8 "$WS/research/cand_q5k/vram_cand.log" 2>/dev/null || echo "(no vram_cand.log)"
echo "== cand_q5k/cand/ contents =="
ls -la --time-style=+%H:%M "$WS/research/cand_q5k/cand/" 2>/dev/null || echo "(no cand dir)"
echo "== cand_q5k.done =="
cat "$WS/research/cand_q5k.done" 2>/dev/null || echo "(no done file)"
echo "== chain processes now =="
pgrep -af cand_q5k_runner || echo "(none)"
