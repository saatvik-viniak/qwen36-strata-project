#!/bin/bash
# temp helper: the apply_q5k failure - find the apply script, its state table, the file's real md5
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== who says 'unexpected state'? =="
grep -rn "unexpected state" /home/dmin/qwen36-strata-kit 2>/dev/null | grep -v "\.o:" | head -5
grep -rn "unexpected state" "$WS/research" 2>/dev/null | head -5
echo "== apply_q5k script location =="
ls -l /home/dmin/qwen36-strata-kit/run/apply_q5k* 2>/dev/null
ls -l "$WS/research"/apply_* 2>/dev/null
echo "== native_expert.cpp md5 (WSL tree, current state) =="
md5sum /home/dmin/qwen36-strata-project/src/kernels/cpu/native_expert.cpp
echo "== the kq lambda region as it stands now (WSL tree) =="
grep -n -A3 "static const bool kq" /home/dmin/qwen36-strata-project/src/kernels/cpu/native_expert.cpp | head -12
echo "== q5k markers still in the file (patched state intact?) =="
grep -c "q5k" /home/dmin/qwen36-strata-project/src/kernels/cpu/native_expert.cpp
echo "== server state =="
curl -s -m 3 http://127.0.0.1:30000/health && echo || echo "(no server)"
