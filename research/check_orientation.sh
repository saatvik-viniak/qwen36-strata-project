#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "now: $(date -u +%F_%TZ)"
echo "== git =="
git -C "$WS" log -6 --oneline
echo "== processes =="
ps aux --width 250 | grep -E "serve_262k|bench|runner|promotion|profile|strata" | grep -v grep || echo "(none)"
echo "== server =="
curl -s -m 3 http://127.0.0.1:30000/health && echo || echo "(no server)"
echo "== binaries =="
cd /home/dmin/qwen36-strata-project/out && md5sum strata strata_q5k_cand strata_q5k_base 2>/dev/null
echo "== profiling-adjacent scripts in research/ =="
ls "$WS/research/" | grep -i -E "profile|prof|pool|band|tlb|thp|s12|host" || echo "(none)"
echo "== serve_262k_q5k.sh (the champion serve) =="
cat "$WS/research/serve_262k_q5k.sh"
echo "== serve_262k.sh (the control serve) =="
cat "$WS/research/serve_262k.sh"
echo "== ncu / perf availability =="
command -v ncu && ncu --version 2>/dev/null | head -2 || echo "(no ncu)"
command -v perf && perf stat --version 2>/dev/null | head -1 || echo "(no perf)"
command -v perf stat 2>/dev/null
echo "== nproc / cpu topology =="
nproc
lscpu 2>/dev/null | grep -E "^CPU\(s\)|Thread|Core" | head -4
