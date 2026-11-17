#!/bin/bash
# temp helper: model.env contents; did the uint4 runner carry MODEL_PATH?; chain state now
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== model.env =="
cat /home/dmin/qwen36-strata-kit/run/model.env
echo ""
echo "== uint4 runner (cand_runner.sh): MODEL_PATH / model.env lines =="
grep -n "MODEL_PATH\|model.env" "$WS/research/cand_runner.sh" || echo "(none in cand_runner.sh)"
echo "== q5k runner: MODEL_PATH / model.env lines =="
grep -n "MODEL_PATH\|model.env" "$WS/research/cand_q5k_runner.sh" || echo "(none in cand_q5k_runner.sh - CONFIRMED MISSING)"
echo "== chain state now =="
tail -3 "$WS/research/cand_q5k.log"
pgrep -af cand_q5k_runner || echo "(chain gone)"
cat "$WS/research/cand_q5k.done" 2>/dev/null && echo "(done file exists)" || echo "(no done file yet)"
