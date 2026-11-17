#!/bin/bash
# Start the 262k int4 server with the Q5_K multi-token kernel ENGAGED (STRATA_KQ256=1).
# Same champion config as serve_262k.sh in every other respect. On a binary without the
# kernel dispatch the env is inert, so the control pass can use serve_262k.sh.
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
export STRATA_KQ256=1
export ENGINE_LOG=/home/dmin/qwen36-strata-project/strata-qwen36.log
# robust stop: kill, then wait for port 30000 to free (max 60 s)
bash /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/stop_server.sh || true
exec ./serve.sh
