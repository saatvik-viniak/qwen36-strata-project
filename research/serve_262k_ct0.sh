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
# robust stop: kill, then wait for port 30000 to free (max 60 s)
bash /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/stop_server.sh || true
exec ./serve.sh
