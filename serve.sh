#!/bin/sh
# Candidate serving entry point: the Strata OpenAI server in front of the
# Qwen3.6-35B-A3B engine path (src/qwen35) for a qwen35moe GGUF.
#
# This is the file an agent edits first. Kernel work lives in src/qwen35/ and is
# picked up by build_kit.sh, which stages this script beside the built engine.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

PORT="${PORT:-30000}"
GGUF="${MODEL_GGUF:?set MODEL_GGUF to a qwen35moe GGUF}"
MODEL_NAME="${MODEL_NAME:-qwen3.6-35b-a3b}"

# Context the engine allocates for at start. Its KV cache is fp32 per token
# (45 KB/token: 11 attention layers x 2 x 2 KV heads x 256 head dim x 4 bytes),
# so 32K = 1.4 GB, 64K = 2.9 GB, 128K = 5.8 GB, 262114 = 11.8 GB.
# The engine refuses a context that does not fit; that is the guard, not a warning.
# Context: an explicit MAX_CONTEXT wins; otherwise it follows the cell the kit is
# measuring (prompt + output + room for the chat template, at least 8K). That is
# what lets a 64K or 128K cell exist at all once the KV cache is quantised.
if [ "${MAX_CONTEXT:-auto}" = "auto" ]; then
  MAX_CONTEXT=$(( ${PROMPT_TOKENS:-0} + ${OUTPUT_TOKENS:-0} + 4096 ))
  [ "$MAX_CONTEXT" -lt 8192 ] && MAX_CONTEXT=8192
fi

# Prompt chunk. auto lets the engine pick from free VRAM (512 on this card);
# 1024 is the default here: bigger chunks feed the expert kernels more rows, and
# 2048 costs ~0.26 GiB more buffers per step, which this card does not have.
PREFILL="${PREFILL:-1024}"

# MTP drafts per step from the GGUF's own MTP block. 0 turns drafting off.
MTP="${MTP:-2}"

# CPU expert/gemm threads. 0 leaves the engine's own pool size.
CPU_THREADS="${CPU_THREADS:-0}"

# The interpreter that has Strata's requirements installed (setup_rig.sh).
PYTHON="${STRATA_PYTHON:-/opt/strata/venv/bin/python}"

# The engine binary: staged beside this script by build_kit.sh, else the tree's
# own build.
BIN="${STRATA_BIN:-$HERE/strata}"
[ -x "$BIN" ] || BIN="$HERE/out/strata"

# The server needs a tokenizer folder (vocab.json, merges.txt, token_type.json),
# not the GGUF's own copy. download_model.sh writes it beside the model.
TOKENIZER_DIR="${TOKENIZER_DIR:-$(dirname "$GGUF")/tokenizer}"
[ -f "$TOKENIZER_DIR/vocab.json" ] || {
  echo "no tokenizer at $TOKENIZER_DIR (no vocab.json)." >&2
  echo "Build it once:  /opt/strata/venv/bin/python $(dirname "$0")/tools/strata_tokenizer.py --gguf \"$GGUF\" --out \"$(dirname "$GGUF")\"" >&2
  exit 1
}

CFG="$HERE/strata-qwen36.json"
LOG="${ENGINE_LOG:-$HERE/strata-qwen36.log}"
MODEL_GGUF="$GGUF" MAX_CONTEXT="$MAX_CONTEXT" PREFILL="$PREFILL" MTP="$MTP" \
CPU_THREADS="$CPU_THREADS" PORT="$PORT" BIN="$BIN" MODEL_NAME="$MODEL_NAME" CFG="$CFG" \
TOKENIZER_DIR="$TOKENIZER_DIR" LOG="$LOG" \
"$PYTHON" - <<'PY'
import json, os
e = os.environ
args = ["--native", e["MODEL_GGUF"], "--max-context", e["MAX_CONTEXT"]]
if e["PREFILL"]:
    args += ["--prefill", e["PREFILL"]]
if e["MTP"]:
    args += ["--mtp", e["MTP"]]
if e["CPU_THREADS"] not in ("", "0"):
    args += ["--cpu-threads", e["CPU_THREADS"]]
cfg = {
    "arch": "qwen35moe",
    "exe": e["BIN"],
    "args": args,
    "model_name": e["MODEL_NAME"],
    "tokenizer": e["TOKENIZER_DIR"],
    "log": e["LOG"],
    "host": "127.0.0.1",
    "port": int(e["PORT"]),
}
with open(e["CFG"], "w") as f:
    json.dump(cfg, f, indent=2)
PY

PYTHONPATH="$HERE" exec "$PYTHON" -m serve.server --engine strata --config "$CFG" --port "$PORT"
