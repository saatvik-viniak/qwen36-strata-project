#!/bin/bash
# serve_262k_q4ks_poolms.sh — the champion config on the poolms-instrumented binary
# (STRATA_BIN=out/strata_poolms) with STRATA_POOLMS=1: trial T2's capture server.
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
export STRATA_BIN=/home/dmin/qwen36-strata-project/out/strata_poolms
export STRATA_POOLMS=1
export ENGINE_LOG=/home/dmin/qwen36-strata-project/strata-qwen36-q4ks262.log
bash /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/stop_server.sh || true
exec ./serve.sh
