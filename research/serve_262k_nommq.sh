#!/bin/bash
# Trial A: expert placement at 262k. STRATA_Q36_NO_MMQ=1 frees the ~1.03 GiB MMQ
# staging pair so the slot guard can place experts in VRAM (it chose 0 slots with MMQ on).
# Cost: the prompt path drops to the native quantized kernels (prefill ~1.7x slower,
# measured earlier); decode is the objective. Everything else identical to the baseline.
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
export STRATA_Q36_NO_MMQ=1
pkill -f serve.server 2>/dev/null
pkill -f out/strata 2>/dev/null
sleep 2
exec ./serve.sh
