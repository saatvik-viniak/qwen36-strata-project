#!/bin/bash
# Trial B: CPU_THREADS=0 (the engine's own pool default) instead of the protocol's 8.
# The engine warns that 8 workers oversubscribe this 6-core CPU.
cd /home/dmin/qwen36-strata-project || exit 1
GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf
export MODEL_GGUF="$GGUF"
export MAX_CONTEXT=262144
export PREFILL=1024
export MTP=2
export CPU_THREADS=0
export PORT=30000
export KV=int4
export SAMPLING='{"presence_penalty":0}'
export ENGINE_LOG=/home/dmin/qwen36-strata-project/strata-qwen36.log
pkill -f serve.server 2>/dev/null
pkill -f out/strata 2>/dev/null
sleep 2
exec ./serve.sh
