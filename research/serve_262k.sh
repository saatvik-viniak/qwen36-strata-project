#!/bin/bash
# Start the 262k int4 server per the mission's baseline protocol (auto-research.md §4).
# Tree: ~/qwen36-strata-project (the verified binary out/strata, 85,072,112 B, built from
# the same tree content that main now carries as 29299a4).
cd /home/dmin/qwen36-strata-project || exit 1
GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf
export MODEL_GGUF="$GGUF"
export MAX_CONTEXT=262144
export PREFILL=1024
export MTP=2
export CPU_THREADS=8
export PORT=30000
export KV=int4
export SAMPLING='{"presence_penalty":0}'
export ENGINE_LOG=/home/dmin/qwen36-strata-project/strata-qwen36.log
# kill any previous server on this port first
pkill -f serve.server 2>/dev/null
pkill -f out/strata 2>/dev/null
sleep 2
exec ./serve.sh
