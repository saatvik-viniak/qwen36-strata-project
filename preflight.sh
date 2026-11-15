#!/bin/sh
# Everything the judge does, done by hand, in the same order. Run this on the rig
# before a campaign exists; each step says what "good" looks like.
#
#   ./preflight.sh            # all steps, engine left running at the end
#   ./preflight.sh --stop     # also stop the engine when done
#
# It needs the model and tokenizer that download_model.sh fetched.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PY="${STRATA_PYTHON:-/opt/strata/venv/bin/python}"
GGUF="${MODEL_GGUF:-/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf}"
PORT="${PORT:-30000}"
STOP="${1:-}"

say() { printf '\n== %s\n' "$*"; }
ok() { printf '   ok: %s\n' "$*"; }
bad() { printf '   FAIL: %s\n' "$*" >&2; exit 1; }

say "1. toolchain"
[ -x "$PY" ] || bad "no interpreter at $PY: run setup_rig.sh"
"$PY" -c 'import numpy, jinja2, regex, yaml' 2>/dev/null || bad "Strata's requirements are missing: run setup_rig.sh"
"$PY" -c 'import transformers' 2>/dev/null || bad "benchmark client needs transformers: sudo $PY -m pip install -r $ROOT/tools/requirements-bench.txt"
. "$ROOT/cuda_env.sh"
strata_find_cuda || { strata_cuda_help; exit 1; }
ok "python $($PY -V 2>&1), cmake $(cmake --version | head -1 | awk '{print $3}'), cuda $CUDA_HOME"

say "2. the build the judge runs (private cmake, python download, no curl needed)"
[ -x "$ROOT/out/strata" ] || bad "no engine yet: run setup_rig.sh"
"$ROOT/build_kit.sh" >/tmp/preflight-build.log 2>&1 || { tail -20 /tmp/preflight-build.log; bad "build_kit.sh failed (log above)"; }
ok "build_kit.sh produced $ROOT/build/strata"

say "3. the family path is compiled in"
"$ROOT/build/strata" --families 2>/dev/null | tr ' ' '\n' | grep -qx qwen35moe \
  || bad "'strata --families' does not list qwen35moe"
ok "qwen35moe"

say "4. weights and tokenizer"
[ -f "$GGUF" ] || bad "no GGUF at $GGUF"
[ -f "$(dirname "$GGUF")/tokenizer/vocab.json" ] \
  || bad "no tokenizer: $PY $ROOT/tools/strata_tokenizer.py --gguf $GGUF --out $(dirname "$GGUF")"
ok "$(basename "$GGUF") ($(du -h "$GGUF" | cut -f1)) and tokenizer/"

say "5. the server answers like the judge expects"
export MODEL_GGUF="$GGUF" MAX_CONTEXT="${PREFLIGHT_CONTEXT:-65536}" PORT
"$ROOT/build/serve.sh" >/tmp/preflight-serve.log 2>&1 &
SERVE=$!
trap 'kill $SERVE 2>/dev/null || true' EXIT INT TERM
i=0
until curl -sf "http://127.0.0.1:$PORT/health" 2>/dev/null | grep -q '"loaded": true'; do
  i=$((i + 1))
  [ "$i" -lt 300 ] || { tail -30 /tmp/preflight-serve.log; bad "server not loaded after 300 s"; }
  sleep 2
done
ok "/health loaded"
curl -sf "http://127.0.0.1:$PORT/v1/models" | grep -q '"id"' || bad "/v1/models did not list a model"
ok "/v1/models"
curl -sf "http://127.0.0.1:$PORT/v1/chat/completions" -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.6-35b-a3b","messages":[{"role":"user","content":"hi"}],"max_tokens":8}' \
  | grep -q '"choices"' || bad "a chat completion failed"
ok "chat completion"
ENGINE_LOG="$ROOT/strata-qwen36.log"
{ grep -h "MTP block loaded" /tmp/preflight-serve.log "$ENGINE_LOG" 2>/dev/null | head -1; } | grep -q . \
  && ok "MTP block loaded (drafting on)" \
  || say "note: no 'MTP block loaded' in either log; drafting is off, the file may lack the MTP block"
{ grep -h "prompt chunk" "$ENGINE_LOG" 2>/dev/null | tail -1 | sed 's/^/   /'; } || true

say "6. the benchmark client, exactly as the kit runs it"
KIT="${KIT_DIR:-$HOME/qwen36-strata-kit}"
[ -d "$KIT" ] || bad "no kit checkout at $KIT: git clone https://github.com/saatvik-viniak/qwen36-strata-kit.git $KIT"
MODEL_PATH="${MODEL_PATH:-/models/qwen36-tokenizer}" \
  "$PY" "$KIT/run/bench.py" --base-url "http://127.0.0.1:$PORT" --model qwen3.6-35b-a3b \
  --prompt-tokens 1 --output-tokens 64 --concurrency 1 --out /tmp/preflight-ctx0.json \
  || bad "the benchmark client failed on ctx0"
ok "ctx0 measured: $(grep -o '"decode_tps": [0-9.]*' /tmp/preflight-ctx0.json || cat /tmp/preflight-ctx0.json)"

say "7. a long prompt fits the context the kit will allocate"
MODEL_PATH="${MODEL_PATH:-/models/qwen36-tokenizer}" \
  "$PY" "$KIT/run/bench.py" --base-url "http://127.0.0.1:$PORT" --model qwen3.6-35b-a3b \
  --prompt-tokens 32768 --output-tokens 64 --concurrency 1 --out /tmp/preflight-ctx32k.json \
  || bad "32K prompt failed: read /tmp/preflight-serve.log"
ok "ctx32k measured: $(grep -o '"decode_tps": [0-9.]*' /tmp/preflight-ctx32k.json || cat /tmp/preflight-ctx32k.json)"

say "8. resources"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader || true
free -g | head -2

if [ "$STOP" = "--stop" ]; then
  kill $SERVE 2>/dev/null || true
fi

printf '\nAll steps passed. A campaign can start from this commit.\n'
