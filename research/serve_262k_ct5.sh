#!/bin/bash
# Trial B': CPU_THREADS=5 (the engine recommends 5 on this 6-core CPU; CT 8 warns
# oversubscribed). Everything else = the frozen baseline §4 config.
cd /home/dmin/qwen36-strata-project || exit 1
GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf
export MODEL_GGUF="$GGUF"
export MAX_CONTEXT=262144
export PREFILL=1024
export MTP=2
export CPU_THREADS=5
export PORT=30000
export KV=int4
export SAMPLING='{"presence_penalty":0}'
export ENGINE_LOG=/home/dmin/qwen36-strata-project/strata-qwen36.log
pkill -f serve.server 2>/dev/null
pkill -f out/strata 2>/dev/null
sleep 2
exec ./serve.sh
