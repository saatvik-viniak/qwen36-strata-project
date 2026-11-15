#!/bin/sh
# Fetch the ready-made qwen35moe GGUF for this fine-tune, and a tokenizer folder
# for the benchmark client.
#
# Strata's Qwen3.6 path reads one GGUF whose architecture is qwen35moe and whose
# own MTP block is intact. llmfan46 publishes exactly that for this fine-tune.
#
# Which quant: the native expert kernels take Q5_K, Q6_K and Q8_0, but not Q4_K
# or Q3_K, because their expert down_proj types are missing from the kernel
# tables (src/kernels/cuda/iq_kernels.cu, STRATA_D_FMTS). Q4_K_M loads the dense
# weights and then refuses the experts. Q5_K_S is the default here: 24.6 GB, and
# this box has 26 GB of RAM.
#
#   ./download_model.sh [QUANT] [DIR] [TOKENIZER_DIR]
set -eu

QUANT="${1:-Q5_K_S}"
DIR="${2:-/models/qwen36-heretic}"
TOKDIR="${3:-/models/qwen36-tokenizer}"

REPO="llmfan46/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-GGUF"
BASE="llmfan46/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved"

# /models is system-wide so the judge's own user can read it; creating it needs
# root the first time.
make_dir() {
  if mkdir -p "$1" 2>/dev/null; then
    :
  else
    echo "creating $1 (needs sudo)"
    sudo mkdir -p "$1"
    sudo chown "$USER" "$1"
  fi
}

if [ -x /opt/strata/venv/bin/hf ]; then
  HF="/opt/strata/venv/bin/hf download"
elif command -v hf >/dev/null 2>&1; then
  HF="hf download"
elif command -v huggingface-cli >/dev/null 2>&1; then
  HF="huggingface-cli download"
else
  echo "no huggingface cli found; installing it into /opt/strata/venv"
  /opt/strata/venv/bin/pip install -q "huggingface_hub[cli]"
  HF="/opt/strata/venv/bin/hf download"
fi

make_dir "$DIR"
make_dir "$TOKDIR"

$HF "$REPO" \
  "Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-${QUANT}.gguf" \
  --local-dir "$DIR"

# Pictures (optional for the campaign, needed if vision is on).
$HF "$REPO" "Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-mmproj-BF16.gguf" \
  --local-dir "$DIR" || true

# The benchmark builds its fixed-length prompt with this tokenizer.
$HF "$BASE" \
  config.json tokenizer.json tokenizer_config.json special_tokens_map.json \
  vocab.json merges.txt chat_template.jinja \
  --local-dir "$TOKDIR" || true

chmod -R a+rX "$DIR" "$TOKDIR"

# Strata's server reads a tokenizer folder, not the GGUF's own copy. The
# extractor in this repo writes vocab.json / merges.txt / token_type.json and the
# model's chat template into $DIR/tokenizer.
GGUF="$DIR/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-${QUANT}.gguf"
if [ -x /opt/strata/venv/bin/python ]; then
  echo "extracting the tokenizer from the GGUF"
  /opt/strata/venv/bin/python "$(dirname "$0")/tools/strata_tokenizer.py" \
    --gguf "$GGUF" --out "$DIR"
  chmod -R a+rX "$DIR/tokenizer"
else
  echo "SKIP tokenizer extraction: /opt/strata/venv missing; run setup_rig.sh then this script again" >&2
fi

echo
echo "GGUF:      $GGUF"
echo "tokenizer: $DIR/tokenizer"
