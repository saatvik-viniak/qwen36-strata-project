#!/bin/sh
# Turn a local GPTQ-Int4 checkpoint into the qwen35moe GGUF Strata reads.
#
#   ./prepare_model.sh [GPTQ_DIR] [QUANT] [OUT_DIR]
#
# Defaults use the checkpoint and folder names from the earlier SGLang setup:
#   /models/qwen36-35b-a3b-gptq-int4   ->   /models/qwen36-heretic
#
# This is a one-time, mostly CPU-bound job. It needs roughly four times the
# packed model's size in free disk (about 165 GB for a 20 GB 4-bit checkpoint),
# because it writes: a dense bf16 copy (~70 GB), a bf16 GGUF (~70 GB), and the
# quantised GGUF (~22 GB). With KEEP=1 the intermediates are kept.
#
# The result has the same weights as your checkpoint. It does NOT gain the MTP
# block: that block was dropped when this checkpoint was made, and the engine
# drafts with the MTP block inside the GGUF. So serve with MTP=0 unless the
# check at the end of this script says otherwise.
set -eu

SRC="${1:-/models/qwen36-35b-a3b-gptq-int4}"
QUANT="${2:-Q4_K_M}"
OUTDIR="${3:-/models/qwen36-heretic}"

VENV="${STAGE_VENV:-$HOME/models/.venv-convert}"
LLAMA="${LLAMA_DIR:-$HOME/src/llama.cpp}"
WORK="${WORK_DIR:-$HOME/models/qwen36-gptq-export}"
JOBS="${JOBS:-$(nproc)}"

say() { printf '\n== %s\n' "$*"; }

[ -f "$SRC/config.json" ] || {
  echo "no config.json in $SRC" >&2
  echo "pass the checkpoint folder as the first argument" >&2
  exit 1
}

make_dir() {
  if mkdir -p "$1" 2>/dev/null; then :; else
    echo "creating $1 (needs sudo)"
    sudo mkdir -p "$1"
    sudo chown "$USER" "$1"
  fi
}
make_dir "$OUTDIR"
make_dir "$WORK"

need_gb=$(SRC_IN="$SRC" python3 - <<'PY'
import glob, os
total = 0
for f in glob.glob(os.environ["SRC_IN"] + "/model-*.safetensors"):
    total += os.path.getsize(f)
# dense bf16 (~3.4x packed), bf16 gguf (~3.4x), quant (~1.1x)
print(int(total * 7.9 / 1e9) + 20)
PY
)
free_gb=$(df -BG --output=avail "$WORK" | tail -1 | tr -dc '0-9')
echo "need about ${need_gb} GB free in $WORK, have ${free_gb} GB"
if [ "$free_gb" -lt "$need_gb" ]; then
  echo "not enough disk; point WORK_DIR at another drive" >&2
  exit 1
fi

say "python environment"
if [ ! -x "$VENV/bin/python" ]; then
  python3 -m venv "$VENV"
fi
"$VENV/bin/pip" install -q -U pip
"$VENV/bin/pip" install -q --index-url https://download.pytorch.org/whl/cpu torch
"$VENV/bin/pip" install -q transformers safetensors accelerate "gptqmodel>=7.1" gguf

say "dequantizing GPTQ to dense bf16"
if [ -d "$WORK/dense" ] && [ "${RESUME:-0}" = "1" ]; then
  echo "resuming $WORK/dense"
  "$VENV/bin/python" "$(dirname "$0")/tools/gptq_dequant.py" "$SRC" "$WORK/dense" --resume
else
  rm -rf "$WORK/dense"
  "$VENV/bin/python" "$(dirname "$0")/tools/gptq_dequant.py" "$SRC" "$WORK/dense"
fi

say "llama.cpp (converter and quantizer)"
if [ ! -d "$LLAMA/.git" ]; then
  git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$LLAMA"
fi
cmake -G Ninja -S "$LLAMA" -B "$LLAMA/build" \
  -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=OFF -DGGML_NATIVE=ON \
  -DLLAMA_CURL=OFF >/dev/null
cmake --build "$LLAMA/build" --target llama-quantize -j "$JOBS"

say "converting to GGUF (bf16)"
"$VENV/bin/pip" install -q -r "$LLAMA/requirements/requirements-convert_hf_to_gguf.txt" 2>/dev/null || true
"$VENV/bin/python" "$LLAMA/convert_hf_to_gguf.py" "$WORK/dense" \
  --outtype bf16 --outfile "$WORK/model-bf16.gguf"

say "quantizing to $QUANT"
"$LLAMA/build/bin/llama-quantize" "$WORK/model-bf16.gguf" \
  "$OUTDIR/qwen36-heretic-${QUANT}.gguf" "$QUANT" "$JOBS"

say "checking the MTP block"
"$VENV/bin/python" - "$OUTDIR/qwen36-heretic-${QUANT}.gguf" <<'PY'
import sys, gguf
r = gguf.GGUFReader(sys.argv[1])
names = [t.name for t in r.tensors]
arch = ""
for f in r.fields.values():
    if f.name == "general.architecture":
        arch = str(bytes(f.parts[f.data[0]]), "utf-8", "replace")
print("architecture:", arch)
print("tensors:", len(names))
has_mtp = any("mtp" in n.lower() for n in names)
print("MTP block:", "present" if has_mtp else "ABSENT")
if arch != "qwen35moe":
    print("WARNING: architecture is not qwen35moe; the engine will not take this file")
if not has_mtp:
    print("No MTP block in this checkpoint: the engine turns drafting off by itself (--mtp 2 is ignored).")
PY

if [ "${KEEP:-0}" != "1" ]; then
  say "freeing intermediates"
  rm -f "$WORK/model-bf16.gguf"
  rm -rf "$WORK/dense"
fi

chmod -R a+rX "$OUTDIR"
say "done"
echo "GGUF: $OUTDIR/qwen36-heretic-${QUANT}.gguf"
