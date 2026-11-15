#!/bin/sh
# Fetch the ready-made qwen35moe GGUF for this fine-tune, and a tokenizer folder
# for the benchmark client.
#
# Strata's Qwen3.6 path reads one GGUF whose architecture is qwen35moe and whose
# own MTP block is intact. llmfan46 publishes exactly that for this fine-tune, so
# nothing is converted. If you want to use a local GPTQ-Int4 checkpoint instead,
# run prepare_model.sh.
#
#   ./download_model.sh [QUANT] [DIR] [TOKENIZER_DIR]
set -eu

QUANT="${1:-Q4_K_M}"
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

echo
echo "GGUF:      $DIR/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-${QUANT}.gguf"
echo "tokenizer: $TOKDIR"
