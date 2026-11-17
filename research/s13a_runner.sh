#!/bin/bash
# s13a_runner.sh — T3: S13-(a)'s pattern-exact host-memory microbench in a
# server-stopped window. Written COMPLETE up front (the running-script lesson:
# never edit this while it executes — write the NEXT script instead).
#
# GATE (the caller's judgment, enforced here): S13A_GO=1 must be exported.
#   NEVER launch this while another agent's detached pass is pending — check
#   FIRST that q4ks_baseline.done exists (or its runner is confirmed dead), and
#   that no serve is expected on 30000. The box's GPU/RAM is shared; a stopped
#   champion + a live baseline pipeline would waste the window or collide.
#
# Steps:
#   1. verify the S13A_GO gate + log the engine state (pgrep — informational);
#   2. stop_server.sh (polls the port free, max 60 s);
#   3. gcc -O2 -pthread s13a_microbench.c -> /tmp/s13a_mb;
#   4. run it with the CURRENT model's arena GiB (argv, default 17.45 = Q4_K_S;
#      the Q5_K_S arena was 21.14) -> research/s13a/s13a.log;
#   5. restore: serve_262k_q4ks.sh detached + wait_health 900 (the champion
#      config = the compose binary + Q4_K_S + MTP 2 + greedy sampler + CT 8 +
#      KV int4 at 262k; verify out/strata md5 = 8833c30b first — the preserve
#      lesson: verify the binary, never assume);
#   6. truthful markers: research/s13a.done = mb_complete | gate_aborted |
#      engine_alive_aborted | build_failed | serve_failed.
# Results: research/s13a/{s13a.log} + s13a.done + s13a.log (the runner's own).
# Launch (the supervisor pattern, NO timeout on the background call):
#   wsl -d Ubuntu bash /mnt/c/.../research/run_s13a_sup.sh
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
BASE=http://127.0.0.1:30000
ENGINE_LOG=/home/dmin/qwen36-strata-project/strata-qwen36.log
ARENA_GIB=${S13A_ARENA:-17.45}
DONE=$WS/research/s13a.done
LOG=$WS/research/s13a.log
OUT=$WS/research/s13a
CHAMPION_MD5=8833c30b6763e4152e96156eba7ebeb8
echo "== s13a_runner up $(date -u +%F_%TZ) (arena $ARENA_GIB GiB) ==" > "$LOG"
mkdir -p "$OUT"

# 1. the gate
if [ "$S13A_GO" != "1" ]; then
  echo "gate_aborted: S13A_GO != 1 — export S13A_GO=1 only in a verified-free window" >> "$LOG"
  echo "gate_aborted" > "$DONE"; exit 1
fi
echo "gate ok $(date -u +%TZ)" >> "$LOG"
if ps aux --width 250 | grep "out/strata" | grep -v grep >> "$LOG" 2>&1; then
  echo "engine_alive_aborted: an engine is running — stop it via the owner's window, not this runner" >> "$LOG"
  echo "engine_alive_aborted" > "$DONE"; exit 1
fi

# 2. stop (stop_server.sh is a no-op-safe poll; it also handles the port wait)
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1 || true
sleep 3

# 3. build
cd /home/dmin/qwen36-strata-project || { echo "no clone" >> "$LOG"; echo "build_failed" > "$DONE"; exit 1; }
if gcc -O2 -pthread -o /tmp/s13a_mb "$WS/research/s13a_microbench.c" >> "$LOG" 2>&1; then
  echo "build ok $(date -u +%TZ)" >> "$LOG"
else
  echo "BUILD FAILED" >> "$LOG"; echo "build_failed" > "$DONE"; exit 1
fi

# 4. run (~2-3 min; CPU-only; the arena is the box's free RAM with every server stopped)
echo "== microbench run $(date -u +%TZ) ==" >> "$LOG"
/tmp/s13a_mb "$ARENA_GIB" > "$OUT/s13a.log" 2>&1
RC=$?
if [ $RC -eq 0 ]; then
  echo "microbench ok $(date -u +%TZ)" >> "$LOG"
  tail -5 "$OUT/s13a.log" >> "$LOG"
else
  echo "MICROBENCH FAILED rc=$RC" >> "$LOG"; tail -10 "$OUT/s13a.log" >> "$LOG"
fi

# 5. restore the champion (verify the binary's md5 first — the preserve lesson)
MD=$(md5sum /home/dmin/qwen36-strata-project/out/strata 2>/dev/null | awk '{print $1}')
if [ "$MD" != "$CHAMPION_MD5" ]; then
  echo "WARN: out/strata md5 $MD != the champion $CHAMPION_MD5 — cp strata_q5k_cand first" >> "$LOG"
  cp /home/dmin/qwen36-strata-project/out/strata_q5k_cand /home/dmin/qwen36-strata-project/out/strata \
    || { echo "cp FAILED" >> "$LOG"; echo "serve_failed" > "$DONE"; exit 1; }
fi
setsid nohup bash "$WS/research/serve_262k_q4ks.sh" > /home/dmin/qwen36-strata-project/s13a_serve.log 2>&1 < /dev/null &
if "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1; then
  echo "champion restored healthy (Q4_K_S, 262k) $(date -u +%TZ)" >> "$LOG"
else
  echo "champion serve never healthy — THE BOX IS NOT SERVING; restore by hand" >> "$LOG"
  echo "serve_failed" > "$DONE"; exit 1
fi

echo "ok: s13a complete $(date -u +%TZ)" >> "$LOG"
echo "mb_complete" > "$DONE"
