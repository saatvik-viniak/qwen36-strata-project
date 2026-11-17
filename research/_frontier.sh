#!/bin/bash
# temp helper: frontier check - the primary agent's recovery progress (read-only)
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== now =="
date -u +%H:%M:%SZ
echo "== git log (last 4) =="
cd "$WS" && git log --oneline -4
echo "== git status: total modified / untracked (mass-M check: ~55 untracked, no mass-add commit) =="
git status --short | grep -c "^M" || true
git status --short | grep -c "^??" || true
echo "== void markers (cleanup ran? forensics kept?) =="
for f in cand_q5k.done promotion.done promotion_v1_void.log; do
  if [ -f "$WS/research/$f" ]; then echo "$f: present: $(head -2 "$WS/research/$f")"; else echo "$f: absent"; fi
done
echo "== promotion/ dir =="
ls -d "$WS/research/promotion" 2>/dev/null || echo "(promotion/ gone - cleanup ran)"
echo "== the four runner fixes present in cand_q5k_runner.sh? =="
grep -n "MODEL_PATH" "$WS/research/cand_q5k_runner.sh" | head -3
grep -n "rm -f" "$WS/research/cand_q5k_runner.sh" | head -3
grep -n "cmp " "$WS/research/cand_q5k_runner.sh" | head -3
echo "== runner mtime =="
stat -c "%y" "$WS/research/cand_q5k_runner.sh"
echo "== kq log patch applied? (WSL tree / Windows tree) =="
grep -c "q5k multi-token kernel" /home/dmin/qwen36-strata-project/src/kernels/cpu/native_expert.cpp 2>/dev/null || echo "0 (WSL)"
grep -c "q5k multi-token kernel" "$WS/src/kernels/cpu/native_expert.cpp" 2>/dev/null || echo "0 (WS)"
echo "== chain processes =="
pgrep -af "cand_q5k_runner|promotion_pass|bench.py|serve_262k|build_kit" || echo "(none)"
echo "== q5k chain log tail =="
tail -3 "$WS/research/cand_q5k.log"
echo "== engine log: the kq engagement line (observability landed?) =="
grep -h "q5k multi-token kernel" /home/dmin/qwen36-strata-project/strata-qwen36.log "$WS/strata-qwen36.log" 2>/dev/null | tail -2 || echo "(no line yet)"
echo "== newest research/ files =="
ls -lt --time-style=+%H:%M "$WS/research" | head -10
