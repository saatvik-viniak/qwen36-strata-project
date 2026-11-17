#!/usr/bin/env bash
# Read-only frontier probe: rig state, model files on disk, serving processes, binaries.
date -u
echo '== /models tree =='
ls -la /models/ 2>/dev/null || echo 'NO /models'
echo
for d in /models/qwen36-heretic /models/qwen36*; do
  [ -d "$d" ] && { echo "== $d =="; ls -la "$d"; }
done
echo
echo '== any gguf under /models (find) =='
find /models -maxdepth 3 -name '*.gguf' -printf '%10s  %p\n' 2>/dev/null | sort -rn
echo
echo '== running strata processes =='
pgrep -a -f strata || echo 'none'
echo
echo '== ports 30000/30001 =='
ss -ltnp 2>/dev/null | grep -E '30000|30001' || echo 'no listeners'
echo
echo '== RAM =='
free -m
echo
echo '== GPU =='
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu,power.draw --format=csv,noheader 2>/dev/null || echo 'no nvidia-smi'
echo
echo '== WSL clone out/ binaries =='
ls -la ~/qwen36-strata-project/out/ 2>/dev/null | grep -E 'strata|\.a$' | head -30
echo
echo '== WSL clone git status =='
cd ~/qwen36-strata-project && git status --short | head -20 && git log --oneline -3 2>/dev/null
echo
echo '== engine log tail =='
tail -40 ~/qwen36-strata-project/strata-qwen36.log 2>/dev/null || find ~/qwen36-strata-project -maxdepth 2 -name 'strata-qwen36.log' 2>/dev/null
