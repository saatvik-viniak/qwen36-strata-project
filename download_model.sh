#!/bin/sh
# Fetch the Qwen3.6-35B-A3B heretic weights Strata can run, and a tokenizer folder
# for the benchmark client.
#
# Strata's Qwen3.6 path reads one GGUF whose architecture is qwen35moe and whose
# own MTP block is intact. llmfan46 publishes exactly that for this fine-tune, so
# nothing is converted and no engine patch is needed for the weights.
set -eu

QUANT="${1:-Q4_K_M}"
DIR="${2:-/models/qwen36-heretic}"
TOKDIR="${3:-/models/qwen36-tokenizer}"

REPO="llmfan46/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-GGUF"
BASE="llmfan46/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved"

mkdir -p "$DIR" "$TOKDIR"

if command -v hf >/dev/null; then
  HF=hf
else
  HF="huggingface-cli download"
fi

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
