#!/bin/bash
# serve_262k_q4ks_mtpoff.sh — trial T1's serving config: the champion config WITHOUT
# the SAMPLING export (the default sampler keeps the MTP drafting off: "drafts
# accepted 0 of 0"), everything else identical to serve_262k_q4ks.sh. The one-flag
# isolation S15-A asked for: the only variable vs the baseline pass is the MTP.
cd /home/dmin/qwen36-strata-project || exit 1
GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q4_K_S.gguf
export MODEL_GGUF="$GGUF"
export MAX_CONTEXT=262144
export PREFILL=1024
export MTP=2
export CPU_THREADS=8
export PORT=30000
export KV=int4
export STRATA_KQ256=1
export ENGINE_LOG=/home/dmin/qwen36-strata-project/strata-qwen36-q4ks262.log
bash /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/stop_server.sh || true
exec ./serve.sh
