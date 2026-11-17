#!/bin/bash
# Trial D: MMQ ON (fast prefill, 1.03 GiB staging) + --expert-slots 2.
# Mission lever B1 (auto-research.md §9.2) at the VRAM edge: the need-check margin is
# ~13 MB (staging 1.03 + slots 0.166 + cpu_out 0.067 <= fr ~1.276 GiB), so the engine
# may refuse — the runner's fast-fail handles that. Expected: +~1.5% decode from 2 hot
# expert slots while KEEPING the fast MMQ prompt path (unlike trial A's NO_MMQ trade).
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
export EXPERT_SLOTS=2
export ENGINE_LOG=/home/dmin/qwen36-strata-project/strata-qwen36.log
# robust stop: kill, then wait for port 30000 to free (max 60 s)
bash /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/stop_server.sh || true
exec ./serve.sh
