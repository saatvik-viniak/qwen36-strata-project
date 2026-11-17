#!/bin/bash
# serve_262k_q5k_poolms.sh — the champion serve (compose config) with
# STRATA_POOLMS=1: the engine's per-step pool accounting line fires
# ('strata pool-ms: <ms> (gu/q/down), N experts, MB, GB/s' on stderr ->
# the engine log) for Lever A's capture. Every other config identical to
# serve_262k_q5k.sh. The POOLMS binary must be on out/strata when this
# runs (the runner guarantees it); with the env unset the line never fires.
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
export STRATA_POOLMS=1
export ENGINE_LOG=/home/dmin/qwen36-strata-project/strata-qwen36.log
bash /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/stop_server.sh || true
exec ./serve.sh
