#!/bin/bash
# serve_262k_q4ks.sh — the Q4_K_S redirect's mission-protocol server:
# the champion serving config (the compose binary, STRATA_KQ256=1, MTP 2,
# greedy sampler, CT 8, KV int4, PREFILL 1024) at 262k server context, on the
# Q4_K_S model file. Same shape as serve_262k_q5k.sh; only the GGUF + log differ.
cd /home/dmin/qwen36-strata-project || exit 1
GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q4_K_S.gguf
export MODEL_GGUF="$GGUF"
export MAX_CONTEXT=262144
export PREFILL=1024
export MTP=2
export CPU_THREADS=8
export PORT=30000
export KV=int4
export SAMPLING='{"presence_penalty":0}'
export STRATA_KQ256=1
export ENGINE_LOG=/home/dmin/qwen36-strata-project/strata-qwen36-q4ks262.log
# robust stop: kill, then wait for port 30000 to free (max 60 s)
bash /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/stop_server.sh || true
exec ./serve.sh
