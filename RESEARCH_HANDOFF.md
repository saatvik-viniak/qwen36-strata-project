# RESEARCH_HANDOFF — qwen36-strata hill climb (262k int4 KV, 2x decode target)

Status at handoff: **in progress — Phase 3 (hill climb): config trials A/B/C running detached**.
Session date: 2026-11-16/17 (rig local CST is UTC-6; bench timestamps UTC).

## What this run is

The instruction file is `auto-research.md` at the repo root (mirrored on origin/main as
`RESEARCH-Q4-KV.md` since ad6ac1f). Mission: (1) land a compatible int4 KV cache, (2)
record the 262k baseline (empty / 32k / 128k prompts, 512-token greedy decode, server
context 262144), (3) climb to 2.00x decode on every cell, (4) hand back a reproducible
tree, numbers, failures and the wall. Work in that order; no speed tuning before the
baseline exists.

## Where things are

| Thing | Value |
| --- | --- |
| Canonical checkout (this workspace) | `C:\Users\Admin\Auto-research-agent\Runtime\projects\saatvik-viniak\qwen36-strata-project` (Windows) |
| Rig | this machine: RTX 3070 8 GB (WDDM), Ryzen 5 3600X, 26 GB RAM, WSL2 Ubuntu `Ubuntu` (user `dmin`, host `Spooky`) |
| Build/serve clone on the rig | `~/qwen36-strata-project` in WSL (its `out/strata`, 85,072,112 B, is the verified final binary; its tree content equals main's 29299a4) |
| Lane clone (pre-existing, PRESERVE) | `~/agent-1-lane` in WSL, commit a64a20b (the int4 KV work, identical content) |
| Kit | `~/qwen36-strata-kit` in WSL at b478ed5; `run/bench.py` is the benchmark client |
| Model | `/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf` (+ tokenizer/ beside it) |
| Bench tokenizer | `/models/qwen36-tokenizer` |
| Python | `/opt/strata/venv/bin/python` |
| Profiling | nsys at /usr/local/bin, ncu in /usr/local/cuda-12.6/bin (WSL) |
| origin | https://github.com/saatvik-viniak/qwen36-strata-project (main) |

## What landed this session (commits on origin/main)

| commit | what |
| --- | --- |
| 29299a4 | the int4 KV cache (packed K/V, per-(kv_head,cell) `__half` scales, opt-in `--kv fp32\|f16\|int8\|int4`, fp32 default bit-for-bit; all paths incl. batch tables, slot copies with scales, MTP block; att_rows uniform 256 rows which is what let 262114 start). Applied from the lane's a64a20b (author preserved: GLM 5.3 Flash (Maya-s quant)); serve.sh conflict resolved (PREFILL 1024 kept, MAX_CONTEXT auto kept) |
| 9f4dac7 | docs/KVNOTE.md + docs/Q4KNOTE.md (the prior sessions' lab notes, source-bound) + PROGRESS.md (the live hill-climb ledger and chart) |
| b81319b | serve.sh: KV default fp32 when unset (mission §4 requires `--kv "${KV:-fp32}"`; the lane's copy defaulted to int4) |

## Measurements so far (see PROGRESS.md and research/NOTEBOOK.md for the full tables)

- 262k server context starts and serves: engine log line `context 262144 cells, prompt
  chunk 1024, KV cache int4, MTP block loaded, 1.28 GiB of VRAM free`; warmed up in
  155.9 s. Placement line: `hybrid experts: 0 of 256 per layer in VRAM (0.00 GiB), all
  21.14 GiB in pageable host memory ... on 9 CPU threads`.
- Baseline cells (empty / ctx32k / ctx128k): see `research/baseline/*.json` and the
  table in PROGRESS.md — filled as they complete.
- Engine warning during baseline: `8 CPU expert workers are configured, but this CPU
  has 6 physical cores ... Recommended: --pool-workers 5`.

## Knowledge that took time to learn this session (do not rediscover)

- The cmd-based shell tool splits on spaces and passes double quotes LITERALLY: never
  quote multi-word args; use single-word tokens or script files. Bash word processing
  also strips double quotes inside an unquoted word: `export SAMPLING={"presence_penalty":0}`
  loses the quotes → JSON parse error; write `SAMPLING='{"presence_penalty":0}'`.
- The write tool produces LF files; bash scripts run via
  `wsl -d Ubuntu bash /mnt/c/.../script.sh` directly.
- WSL-side: `sed -i s/\r//g` arrives as `s/r//g` (one backslash eaten) and deletes every
  letter r — do NOT edit files that way.
- The server binds the port only AFTER the engine finishes loading; connection-refused
  during `still starting (N s)` is normal (262k start ≈ 280-300 s total).
- At 262k with MMQ on, the engine places 0 expert slots (free VRAM 1.28 GiB − MMQ
  staging 1.03 GiB − reserve 0.77 GiB < 0). `STRATA_Q36_NO_MMQ=1` frees the staging pair
  and should raise the slot cap — trial A, scripted in `research/serve_262k_nommq.sh`.
- GPU peaks observed: 6397 MiB after load, 7520 MiB during warmup (guard 7.9 GiB; the
  prompt staging at 128k adds ~0.64 GiB — inside the guard by the engine's own fit math).

## Prior-session facts carried forward (source-bound; see docs/KVNOTE.md, docs/Q4KNOTE.md)

- int4 KV verified: VERIFY=1 0/6103 mismatches (all dtypes), pinned-placement fp32 gate
  10/10 bit-identical to the old binary, cache-content dumps within envelope (int4 worst
  K 8.3% / V 6.9% relative), needle answers correct at 32k/64k/128k prompts.
- Serving at 32k ctx (NOT the 262k protocol): fp32 21.4 / int4 28.8 empty; with the
  greedy-sampler config (SAMPLING presence_penalty 0 → MTP drafting engages; was 0 of 0
  accepted under the model card's presence_penalty 1.5 default) fp32 26.1 / int4 34.0
  empty; MTP 2 beats MTP 4 (34.0 vs 32.0); CT 12 harmful; CT 8 with MMQ off best
  (48.1 tok/s on the Q4_K_M file at 32k).
- Q4_K files load since the X(12) patch (Q4K-DOWN-PROMPT.md); the model file is FIXED
  for this mission (Q5_K_S), so Q4_K weights are a new-baseline exploration, not a
  candidate for the 2x target.

## Open obligations (next steps)

1. Finish the 262k baseline (3 cells), fill PROGRESS.md + NOTEBOOK.md, commit, push.
2. Trial A: STRATA_Q36_NO_MMQ=1 (scripted) — expert slots at 262k. Measure all cells.
3. Trial B: CPU_THREADS 0 vs 8 (the engine recommends 5 pool workers on this 6-core CPU).
4. Trial C: MTP depth 3/4 and batch-mtp at 262k (acceptance changes with context).
5. §9.0 wall profiling with nsys/ncu once the GPU is free (never while measuring).
6. Parity evidence per cell (fp32 reference is unattainable at 262k by design — report
   the gates at 32k + needle correctness + state that plainly; do NOT claim a 0.95 ratio
   that was not measured).
7. Keep the lab notebook appended after EVERY run, including failures.
8. Commit sign-off: all commits authored GLM 5.3 Flash (Maya-s quant), no co-author line.

## Session 2026-11-17 continuation (skill install + ceilings + repeat passes)

- The `inference-optimisation` skill (github.com/sybil-solutions/inference-optimisation-skill)
  is installed at `C:\Users\Admin\.config\opencode\skills\inference-optimisation\` (loads via
  the skill tool) and vendored in-repo at `research/skill/inference-optimisation/`. Its loop
  (ceilings first, ledger, A/B with controls, serialize GPU, watchdog) is applied in
  `research/hillclimb/` (PLAN.md, THEORY.md, ledger.jsonl, configs/).
- Baseline repeats: empty 21.86 (0.3% spread, no pass 3 needed); ctx32k pass-2 20.44
  (recovered from the engine log after the pass-2 background job was KILLED AT A HARNESS
  CHECKPOINT — archived as research/baseline/pass2/ctx32k.json), pass-3 19.52 → ctx32k
  median 19.52. ctx128k pass-2/pass-3 re-running detached (`lean_bench128k.sh`).
- Harness checkpoints kill background jobs at turn end: anything long-running MUST be
  `setsid nohup`-detached INSIDE WSL, and the launcher must keep the wsl.exe client alive
  ~4 s past spawn (proven: the probe-spawned server survived its client's exit). Kill the
  BENCH CLIENT, never the server, mid-run (the server aborts the request cleanly and even
  reuses the partial prompt's KV: 110592 of 124530 tokens reused after the cancel).
- `bench.py` runs warmup+measured INTERNALLY per invocation (two engine sessions, reports
  the second) — an external warmup doubles the ctx128k prefill cost. One invocation per
  round is the lean protocol; skip pass-3 when the spread vs pass-1 is ≤ 2%.
- GGUF header parsed (custom KV dialect: STRING=8 u64-len, ARRAY=9; scripts in
  research/gguf_*.py): 41 blocks, 256 experts top-8, n_ff 512, vocab 248320, 16Q/2KV×256,
  full-attn every 4th block (≈11 KV layers), GDN rest, nextn MTP block. Expert pool =
  41×3×268.4M×0.6875 B = 22.70 GB = the engine's 21.14 GiB ✓. KV int4 = 5632 B/token
  (serve.sh's comment agrees: 5.7 KB) → 0.738 GB per verify step at 128k.
- Ceiling verdict (research/hillclimb/THEORY.md): the pool STREAMS at 44 GB/s (prior
  measurement) so reads are ~14 ms/step; the empty/32k wall is the pool's COMPUTE
  (~3.1 GMACs/verify-step at ~55-80 GFLOPS effective ≈ 102 ms) + overheads; the 128k wall
  adds the int4 attention kernel (~0.738 GB/step, byte-granular reads ≈ 74-95 ms).
  2x targets are feasible at pool ~2x compute rate + attention kernel fix.
- Pool kernel anatomy: Q5_K_S experts fall through to ggml-cpu's per-(row,token) `vec_dot`
  singleton loop (src/kernels/cpu/native_expert.cpp dispatch; KQ256 opt-in measured
  1.01-1.13x in parity, "no faster in the engine"). THP is `madvise` with 0 anon hugepages;
  the 21.14 GiB arena runs on 4k pages; RAM at 24/25 GiB used (hugepages may struggle).
- Commit identity fixed: `.git/config` now has user.name GLM 5.3 Flash (Maya-s quant)
  (commits 9f4dac7/b81319b/78f49c2 used the repo's default SpookyTryhards identity before
  this was noticed; left as-is rather than force-push, noted here for provenance).
- Trial scripts ready: serve_262k_ct5.sh (CT 5), serve_262k_nommq.sh (slots), serve_262k_mtp3.sh;
  trial_runner.sh runs them sequentially (waits for lean_bench.done) with a VRAM watchdog
  (>8090 MiB kills the bench), writing research/trials/<trial>/<cell>.json.

## Guard status

- Peak VRAM < 7.9 GiB: watching (7520 MiB seen in warmup; cell peaks in the JSONs).
- System RAM < 24 GiB: 26 GB box, model 24.6 GB mmap'd — watch `free -m` during runs.
- No OOM, no truncated cache: the engine refuses loudly (never bypass it).
- Text parity: gates at 32k done (prior session); per-cell evidence = needle answers +
  the fixed prompt set; the fp32@262k reference does not exist (11 GiB cache).

## Session 2026-11-17 continuation #2 (baseline complete + port-race fix + trials running)

- BASELINE COMPLETE (262k server ctx, KV int4, MTP 2, CT 8, greedy sampler, peaks
  7.35-7.38 GiB): empty 21.92 (rep 21.86, spread 0.3% → no pass 3), ctx32k median 19.52
  of {18.94, 20.44, 19.52}, ctx128k median 11.80/11.66 (spread 1.19% → pass 3 skipped).
  Promotion medians: 21.89 / 19.52 / 11.73. Evidence in research/baseline/pass*/.
- **Failure + root cause (trial A nommq, first launch)**: the trial server died at
  startup with "port 30000 already in use" — the still-running baseline server needed
  >2 s past SIGTERM to release the socket; the old serve scripts slept exactly 2 s, and
  trial_runner burned its 900 s health wait polling a dead port. The stuck runner (pid
  27702) was killed; client-side only (kill_trials.sh).
- **Fix (commit f73a906)**: research/stop_server.sh kills the server + engine and then
  POLLS port 30000 until free (max 60 s); ALL five serve_262k*.sh call it before
  `exec ./serve.sh`. Helper scripts added: kill_trials.sh, check_trials.sh,
  check_trialserver.sh, check_soon.sh (commit f448c10).
- Shell-tool lesson (new): `wsl bash -c "sleep 210 && ..."` loses the inner quotes to
  cmd — always put sleeps/logic in a script file and run
  `wsl -d Ubuntu bash /mnt/c/.../script.sh`.
- **Trials A (nommq) → B (ct5) → C (mtp3) relaunched detached** (pid 27821, 4-s
  keep-alive; runner gate lean_bench.done passes immediately). Results land in
  research/trials/<trial>/<cell>.json + vram.log; the runner restores the champion
  baseline server at the end and writes trial_runner.done.
- Verdict rules for the trials (skill §A/B): each trial is a one-change A/B vs the
  baseline medians; a winner needs control-candidate-control re-measure before
  promotion (recorded in research/hillclimb/ledger.jsonl); any peak > 8090 MiB →
  rejected by watchdog, recorded as such.
- Next after the trials: §9.0 profiling (research/profile_pool.sh via perf during a
  live decode; research/profile_gpu.sh via nsys/ncu) to split pool compute vs
  per-layer phase barriers (41 calls/step × 2 phases) vs the int4 attention read at
  128k; then kernel work (int4 attention 128-bit loads, pool phase-barrier reduction,
  MADV_HUGEPAGE on the 21.14 GiB arena) — in that evidence order.

## Session 2026-11-17 continuation #3 (user rules + trial verdicts + trial D)

- **USER RULES (binding)**: (1) no single benchmark expected to exceed 30 minutes —
  skip it or slot the context down (16k/32k acceptable); (2) another agent posts
  SUGGESTIONS.MD in the workspace with optimization ideas: check it briefly every
  ~15 min while an optimization runs, act on worthwhile items, and annotate what
  worked vs what hasn't back into that file so the other agent can see outcomes.
- **Failure + fix (runner swap)**: the original trial runner would have burned ~65
  min on nommq/ctx128k (native-kernel prefill ~70 tok/s). research/watch_and_swap.sh
  (detached, pid 33540) killed it the moment nommq/ctx32k.json landed and spawned
  research/trial_runner2.sh — which hard-fails a dead server (5 consecutive
  pgrep-miss seconds; the kit's wait_health.py alone polls 900 s past a death).
- **Trial A (nommq) REJECTED (pending control re-measure)**: empty 23.00 (+5.1%),
  ctx32k 18.64 (−4.5% vs 19.52 — below the baseline's whole spread), ctx128k
  skipped (budget rule). Mechanism: 7 slots help empty but hurt at 32k (likely
  slot-replacement churn), and the prompt path regressed 3.4× (MMQ → native).
- **Placement math grounded** (src/qwen35/q36_engine.cu, place_experts): MMQ staging
  = 2×(max_layer+tail) = 1.03 GiB (one layer's full 256-expert set, double-buffered);
  slots = (fr − 768 MiB reserve) − staging, hard-clamped to fr − staging − 512 MiB;
  `--expert-slots N` bypasses the budget but must pass the need-check vs actual free
  VRAM. With MMQ on (fr ≈ 1.28 GiB): S=2 passes by ~13 MB, S=3 fails. MMQ prefill
  streams the whole 21.14 GiB pool per 1024-token chunk → PCIe-bound ≈ 5.4 GB/s →
  matches the measured 240-280 tok/s.
- **Trial queue** (trial_runner2.sh, detached): ct5 → mtp3 → mmqslots2 (NEW: MMQ +
  --expert-slots 2, mission lever B1 at the VRAM edge, config-only, keeps the fast
  MMQ prompt path; serve_262k_mmqslots2.sh) → champion restore. Partial: ct5 empty
  21.69 (−0.9%), ctx32k 19.33 (−1.0%) — washing out.
- Composition recipe for the kernel phase: shrink the MMQ staging sub-chunks ~4×
  (code) so 7 slots coexist with the fast MMQ prefill — composes trial A's +5.1%
  empty decode with the baseline's prefill path. Caveat grounded in the rebalance
  code: swaps are ≤8 per 32 rows, each a blocking 2.06 MB H2D + sync (~2-3 ms/step
  at 7 slots; scores ×0.5 per pass; 2048-swap pass after prompts) — the slots' 32k
  churn needs a B2-style fix (non-blocking swap stream / weaker decay / context-
  scaled kRebalanceEvery) or the composition inherits trial A's 32k regression.
  Trial D's ctx32k (S=2, MMQ prefill) is the cheap sign test.

## Session 2026-11-17 continuation #4 (ct5 verdict + runner death + candidate staged)

- **Trial B (ct5) REJECT — complete**: empty 21.69 (−0.9%), ctx32k 19.33 (−1.0%),
  ctx128k 11.71 (−0.2%). The engine's own 5-worker recommendation does not beat the
  frozen CT 8 on this workload. CT 8 stays.
- **FAILURE (self-inflicted), root cause + lesson**: trial_runner2 died at 03:30:23Z —
  I REWROTE the script with the write tool at ~03:05Z while it was executing (started
  02:54Z); bash resumed at its saved byte offset in the CHANGED file and died on a
  syntax error ("syntax error near unexpected token '&&'"). mtp3 + mmqslots2 never
  ran; the champion restore never ran; the CT 5 server stayed on the port. LESSON
  (violated my own rule): NEVER edit or rewrite a running script — write the NEXT
  script complete instead.
- **Recovery**: trial_runner3.sh (mtp3 → mmqslots2 → champion restore; written
  complete up front; pid 46258) runs detached; cand_runner.sh (pid 46326) waits for
  trial_runner3.done and then runs the uint4 candidate chain: preserve
  out/strata_byte_loop → build_kit.sh → stop the champion (VRAM must be free) →
  STRATA_Q36_VERIFY=1 (--tokens 1..8 --n 16; 0 mismatches required) →
  q36_solo_gate.py on both binaries + q36_cmp_gate.py (bit-identical required) →
  serve the champion config on the new binary → bench empty/ctx32k/ctx128k (each
  fits the 30-min rule). Any verification failure restores the byte-loop champion.
- **WSL clone trap (do not pull)**: the clone ~/qwen36-strata-project carries the
  int4 KV work as LOCAL UNCOMMITTED edits (its HEAD d548533 predates it; dirty:
  serve.sh, src/kernels/cuda/iq_kernels.cu, src/qwen35/q36_engine.cu). A git pull
  would conflict with the dirty q36_engine.cu — the uint4 candidate (dd9fee1) was
  applied there directly via research/apply_uint4.py (idempotent string replace).
- The uint4 candidate's parity claim to verify: same nibble order + same
  accumulation order → bit-identical; 16× fewer L1 transactions on a kernel measured
  45-57× above the 448 GB/s DRAM floor.
- **Next kernel lever, fully grounded (the empty/32k compute wall)**: the model's
  experts are Q5_K (type 13) ×41 gate/up AND down; the pool's dispatch has
  multi-token AVX-2 kernels only for IQ/trellis/NVFP4/kq types 12/7/8 — Q5_K falls
  to ggml-cpu's **AVX1-build generic scalar dot** per (row, token) (the vendored
  ggml's AVX2 branch exists but is compiled out; third_party/strata-ggml/.../arch/
  x86/quants.c:2216). block_q5_K = {d, dmin, scales[12], qh[32], qs[128]} = 176 B
  (0.6875 B/val ✓); activation = q8_K. Project: a Q5_K multi-token AVX-2 kernel in
  kq_avx2.cpp (mirror q4k_dot's NT structure; the bit reference is the GENERIC path
  — the AVX2 branch rounds differently per #2215's guard) + dispatch in
  native_expert.cpp (gu: f.gu_type == 13, nt ≥ mt_min; down: extend the kq256
  branch to d_type == 13). Precedent: the existing kernels measure 2.0-2.4× ggml at
  3 tokens; MTP 2 always runs 3-token windows. Expected: pool ~102 ms/step →
  ~45-55 ms → empty ~30-38 tok/s.
- **Pipeline state** (all detached): trial_runner3 (pid 46258): mtp3 empty 20.81
  (−4.9%, reject pending cells) → mmqslots2 → champion restore →
  trial_runner3.done; then cand_runner (pid 46326) runs the uint4 chain (build →
  VERIFY → gates → 3-cell bench) → cand_uint4.done. Estimated all-done ~05:45Z.
  SUGGESTIONS.MD still absent (checked every turn).
