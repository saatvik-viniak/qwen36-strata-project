#!/bin/bash
# serve_262k_q5k_w.sh — the champion serve (compose binary, STRATA_KQ256=1) with
# CPU_THREADS taken from the environment (S12 lever C's worker-count test);
# defaults to 8 (the champion config) when unset. Same every other config as
# serve_262k_q5k.sh. No stop inside — the caller controls stops.
cd /home/dmin/qwen36-strata-project || exit 1
GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf
export MODEL_GGUF="$GGUF"
export MAX_CONTEXT=262144
export PREFILL=1024
: "${CPU_THREADS:=8}"
export CPU_THREADS
export MTP=2
export PORT=30000
export KV=int4
export SAMPLING='{"presence_penalty":0}'
export STRATA_KQ256=1
export ENGINE_LOG=/home/dmin/qwen36-strata-project/strata-qwen36.log
exec ./serve.sh
