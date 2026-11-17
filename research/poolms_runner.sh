#!/bin/bash
# poolms_runner.sh — Lever A: the STRATA_POOLMS build + gate + capture (the
# pool/attention split measurement that perf/ncu cannot provide on this box).
#   1. stop every engine (the 65536-ctx leftover on 30001 has an unrecorded
#      purpose — handoff #21 records the stop reason: the 21.14 GiB arena
#      cannot coexist with another engine in 25.4 GiB, and the solo gate
#      needs the memory);
#   2. apply_poolms.py (md5-guarded, both trees);
#   3. rm -f out/strata + build_kit.sh (~42 s) + the tautology guard;
#   4. THE GATE: the POOLMS binary's solo gate output with
#      STRATA_KQ256=1 and STRATA_POOLMS UNSET must be byte-identical to the
#      compose's recorded research/cand_q5k/new.json (the kqlog precedent:
#      default OFF = byte-identical). The parity tree is NOT re-run — the
#      patch touches no kernel (pool.cpp scheduling/timing only); the kernel
#      sources are unchanged since the v6 parity receipt.
#   5. THE CAPTURE: serve the champion config with STRATA_POOLMS=1, wait
#      health, settle 900 s (the promotion protocol — comparable to the
#      compose-clean cell), bench empty (512 tok, greedy, concurrency 1),
#      the engine-log slice captured (the pool-ms lines + the q5k
#      engagement line);
#   6. restore the champion (cp strata_q5k_cand -> out/strata +
#      serve_262k_q5k.sh), the POOLMS binary preserved at out/strata_poolms.
# Results: research/poolms/{gate.json,empty.json,engine.log} + poolms.done
# (truthful: bench_complete or <stage>_failed).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
BASE=http://127.0.0.1:30000
GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf
export MODEL_PATH=/models/qwen36-tokenizer
C=$WS/research/poolms
DONE=$WS/research/poolms.done
LOG=$WS/research/poolms.log
ENGINE_LOG=/home/dmin/qwen36-strata-project/strata-qwen36.log
FAIL=0
echo "== poolms_runner up $(date -u +%F_%TZ) ==" > "$LOG"
mkdir -p "$C"
rm -f "$DONE"

# 1. stop every engine (the 30001 leftover included: pkill catches all)
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1 || true
sleep 3
if ps aux --width 250 | grep "out/strata" | grep -v grep >> "$LOG" 2>&1; then
  echo "WARN: an engine still lives" >> "$LOG"
else
  echo "no engine left $(date -u +%F_%TZ)" >> "$LOG"
fi

# 2. apply the patch
cd /home/dmin/qwen36-strata-project || exit 1
if python3 "$WS/research/apply_poolms.py" >> "$LOG" 2>&1; then
  echo "patch applied $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "apply_poolms FAILED" >> "$LOG"; echo "apply_failed" > "$DONE"; exit 1
fi

# 3. build (the no-op fix: rm first) + the tautology guard
rm -f /home/dmin/qwen36-strata-project/out/strata
echo "out/strata removed $(date -u +%F_%TZ)" >> "$LOG"
if bash build_kit.sh >> "$LOG" 2>&1; then
  echo "build ok $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "BUILD FAILED" >> "$LOG"; echo "build_failed" > "$DONE"; exit 1
fi
md5sum /home/dmin/qwen36-strata-project/out/strata >> "$LOG"
if cmp -s /home/dmin/qwen36-strata-project/out/strata /home/dmin/qwen36-strata-project/out/strata_q5k_base; then
  echo "BUILD NO-OP: candidate == base $(date -u +%F_%TZ)" >> "$LOG"
  echo "build_noop" > "$DONE"; exit 1
fi
cp /home/dmin/qwen36-strata-project/out/strata /home/dmin/qwen36-strata-project/out/strata_poolms \
  || echo "WARN: could not preserve the POOLMS binary" >> "$LOG"
echo "POOLMS binary preserved at out/strata_poolms $(date -u +%F_%TZ)" >> "$LOG"

# 4. the text gate (POOLMS unset: the default-off output must equal the compose's)
if STRATA_KQ256=1 "$PY" tools/qwen35/q36_solo_gate.py --exe /home/dmin/qwen36-strata-project/out/strata \
     --args "--native $GGUF --max-context 32768 --kv int4 --no-graph" --out "$C/gate.json" >> "$LOG" 2>&1; then
  echo "gate run ok (STRATA_KQ256=1, POOLMS unset) $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "gate run FAILED" >> "$LOG"; echo "gate_failed" > "$DONE"; exit 1
fi
if "$PY" tools/qwen35/q36_cmp_gate.py "$WS/research/cand_q5k/new.json" "$C/gate.json" >> "$LOG" 2>&1; then
  echo "cmp gate PASS (bit-identical to the compose with POOLMS unset) $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "cmp gate DIFFERS $(date -u +%F_%TZ)" >> "$LOG"; echo "gate_differs" > "$DONE"; exit 1
fi

# 5. the capture (the champion config + STRATA_POOLMS=1)
BEFORE=$(wc -l < "$ENGINE_LOG" 2>/dev/null)
[ -z "$BEFORE" ] && BEFORE=0
echo "== capture serve $(date -u +%F_%TZ) (engine log line $BEFORE) ==" >> "$LOG"
setsid nohup bash "$WS/research/serve_262k_q5k_poolms.sh" > /home/dmin/qwen36-strata-project/poolms_launch.log 2>&1 < /dev/null &
if "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1; then
  echo "server healthy (STRATA_POOLMS=1) $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "server never healthy" >> "$LOG"; echo "server_failed" > "$DONE"; exit 1
fi
echo "settling 900 s $(date -u +%F_%TZ)" >> "$LOG"
sleep 900
echo "settle done $(date -u +%F_%TZ)" >> "$LOG"
echo "== CELL empty $(date -u +%F_%TZ) ==" >> "$LOG"
if "$PY" /home/dmin/qwen36-strata-kit/run/bench.py --base-url "$BASE" --model qwen3.6-35b-a3b \
     --prompt-tokens 1 --output-tokens 512 --concurrency 1 \
     --out "$C/empty.json" >> "$LOG" 2>&1 \
   && [ -s "$C/empty.json" ] && grep -q decode_tps "$C/empty.json" 2>/dev/null; then
  echo "bench empty measured $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "bench empty FAILED" >> "$LOG"; FAIL=1
fi
tail -n +$((BEFORE + 1)) "$ENGINE_LOG" > "$C/engine.log" 2>/dev/null
N=$(grep -c "strata pool-ms" "$C/engine.log" 2>/dev/null)
echo "pool-ms lines: ${N:-0}" >> "$LOG"

# 6. restore the champion (the compose binary, no env)
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1 || true
cp /home/dmin/qwen36-strata-project/out/strata_q5k_cand /home/dmin/qwen36-strata-project/out/strata \
  || { echo "cp FAILED" >> "$LOG"; FAIL=1; }
md5sum /home/dmin/qwen36-strata-project/out/strata >> "$LOG"
setsid nohup bash "$WS/research/serve_262k_q5k.sh" > /home/dmin/qwen36-strata-project/serve_262k_launch.log 2>&1 < /dev/null &
if "$PY" /home/dmin/qwen36-strata-kit/run/wait_health.py "$BASE/health" 900 >> "$LOG" 2>&1; then
  echo "champion restored healthy (compose, no env) $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "champion serve never healthy - THE BOX IS NOT SERVING; restore by hand" >> "$LOG"; FAIL=1
fi
if [ "$FAIL" -eq 0 ]; then
  echo "ok: poolms capture complete $(date -u +%F_%TZ)" >> "$LOG"
  echo "bench_complete" > "$DONE"
else
  echo "poolms completed WITH failures - the marker never lies $(date -u +%F_%TZ)" >> "$LOG"
  echo "bench_failed" > "$DONE"
fi
