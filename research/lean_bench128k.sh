#!/bin/bash
# lean_bench128k.sh — ctx128k pass-2 (1 invocation; bench.py warms internally),
# then pass-3 ONLY if pass-2 differs from pass-1 (11.80) by more than 2%.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
KIT=/home/dmin/qwen36-strata-kit
PY=/opt/strata/venv/bin/python
export MODEL_PATH=/models/qwen36-tokenizer
BASE=http://127.0.0.1:30000
DONE=$WS/research/lean_bench.done
rm -f "$DONE"
mkdir -p "$WS/research/baseline/pass2" "$WS/research/baseline/pass3"

echo "== lean bench start $(date -u +%F_%TZ) =="
"$PY" "$KIT/run/wait_health.py" "$BASE/health" 300 || { echo "fail: no health" > "$DONE"; exit 1; }

echo "== ctx128k pass-2 (1 invocation) $(date -u +%F_%TZ) =="
"$PY" "$KIT/run/bench.py" --base-url "$BASE" --model qwen3.6-35b-a3b \
  --prompt-tokens 131072 --output-tokens 512 --concurrency 1 \
  --out "$WS/research/baseline/pass2/ctx128k.json"

P2=$("$PY" - <<'EOF'
import json
try:
    print(json.load(open("/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/baseline/pass2/ctx128k.json"))["decode_tps"])
except Exception:
    print("0")
EOF
)
echo "pass-2 decode_tps = $P2"
SPREAD=$("$PY" -c "print(abs($P2 - 11.80) / 11.80)")
echo "spread vs pass-1 = $SPREAD"

NEED3=$("$PY" -c "print(1 if $SPREAD > 0.02 else 0)")
if [ "$NEED3" = "1" ]; then
  echo "== ctx128k pass-3 (spread $SPREAD > 2%) $(date -u +%F_%TZ) =="
  "$PY" "$KIT/run/bench.py" --base-url "$BASE" --model qwen3.6-35b-a3b \
    --prompt-tokens 131072 --output-tokens 512 --concurrency 1 \
    --out "$WS/research/baseline/pass3/ctx128k.json"
else
  echo "== ctx128k pass-3 SKIPPED (spread $SPREAD <= 2%) =="
fi

echo "ok: lean bench done $(date -u +%F_%TZ)" > "$DONE"
echo "== lean bench end $(date -u +%F_%TZ) =="
