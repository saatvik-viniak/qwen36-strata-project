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
MAX_CONTEXT="${MAX_CONTEXT:-32768}"

# Prompt chunk: auto lets the engine pick (2048 in the hybrid mode), 512 is the
# base engine's text bit for bit.
PREFILL="${PREFILL:-auto}"

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

CFG="$HERE/strata-qwen36.json"
MODEL_GGUF="$GGUF" MAX_CONTEXT="$MAX_CONTEXT" PREFILL="$PREFILL" MTP="$MTP" \
CPU_THREADS="$CPU_THREADS" PORT="$PORT" BIN="$BIN" MODEL_NAME="$MODEL_NAME" CFG="$CFG" \
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
    "host": "127.0.0.1",
    "port": int(e["PORT"]),
}
with open(e["CFG"], "w") as f:
    json.dump(cfg, f, indent=2)
PY

PYTHONPATH="$HERE" exec "$PYTHON" -m serve.server --engine strata --config "$CFG" --port "$PORT"
