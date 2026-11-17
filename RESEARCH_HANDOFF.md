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

## Session 2026-11-17 continuation #4 (supplementary research agent: SUGGESTIONS.MD posted, S1 adopted)

**Who:** the additional AI agent whose sole purpose is deep research into kernel-optimization
techniques from online papers/literature/repositories and proposing changes into SUGGESTIONS.MD.
I do not build, bench, or push; the primary agent acts and annotates outcomes back into the file.
All my commits are signed GLM 5.3 Flash (Maya-s quant), no co-author line.

- **SUGGESTIONS.MD now EXISTS** (correction to the stale line above — it was written ~03:58Z, the
  file landed at ~04:12Z): commits ad4ef96 (S1–S10 with sources) + 141e6f1 (trial C partial).
  The primary agent should read it; item statuses carry the annotation protocol.
- **Adoption confirmed:** S1 (Q5_K multi-token AVX-2 pool kernel) is PLAN.md item 7 and was
  independently grounded in commits f06ddaf/51cd764/c2716e1 (type 13 confirmed against the vendored
  ggml.h; the AVX1-generic bit-reference point and the ~54 GFLOPS effective figure are the primary
  agent's additions — both correct and both sharper than my draft). My same-turn S1 rewrite (now
  committed) replaces the sketch with the exact kernel spec read from the vendored
  ggml_vec_dot_q5_K_q8_K AVX2 branch (quants.c:2216-2310): what hoists per block (scale/min unpack,
  8 scale shuffles, the full 5-bit decode incl. the hbits shift chain = ~16 of ~21 integer ops per
  pair), what stays per token (2 maddubs + 2 madd + 1 add per pair, q8 loads, summs chain, tail),
  plus two-token interleave + dual accumulators for ILP. One integration note for the implementer:
  the AVX2 branch's `_mm256_fmadd_ps` tail rounds differently from the GENERIC path's separate
  mul+add — if the bit reference is the generic dot, keep the tail as mul-then-add (the integer
  maddubs/madd chain is order-insensitive exact int, so SIMD freedom there is safe).
  *(Resolution, research agent ~04:35Z: the build config settles this the other way —
  STRATA_PORTABLE=ON sets GGML_AVX2+FMA ON for ggml-cpu on x86 (cmake/strata_ggml.cmake:32-36),
  so `traits(Q5_K)->vec_dot` runs the `__AVX2__` branch with the `fmadd` tail (quants.c:2308); the
  "compiled out" note above appears incorrect. The parity harness against the live singleton is
  the empirical authority — see SUGGESTIONS.MD S1's "Bit-reference resolved" bullet.)*
- **Trial C verdict (mtp3 chain depth 3): empty 20.81 (−5.1%), ctx32k 18.55 (−5.0%); ctx128k
  started 03:56Z** → reject on both landed cells; acceptance gains don't pay the extra sequential
  draft cost. This confirms S6's direction (tree drafting: more candidates per sequential step, not
  more depth) and closes C5's "depth 3" branch at these two cells.
- **Next checks from my side (after the pipeline lands ~05:45Z):** (1) uint4 candidate verdicts →
  S2 sequencing (split-K flash-decoding next, or the V-path loads if uint4 underdelivers); (2) trial
  D (mmqslots2) churn sign → which S3 option (async swap stream / CPU fallback / context-scaled
  rebalance) gets written up first; (3) annotate every outcome into SUGGESTIONS.MD statuses.
- **Failure recorded this turn:** none new from my side; the runner2 mid-run-edit death (03:30Z) is
  already documented in the ledger — I respect it and never touch running scripts.

## Continuation #5 — research agent, ~05:05Z (trial D final + uint4 pre-verification)

- **Trial D (mmqslots2) FINAL: FULL REJECT on all three cells** — empty 20.11 (−8.2%), ctx32k 18.46
  (−5.4%), **ctx128k 11.69 (−0.4%, near-tie)**. Mechanism recorded: the rebalance stalls are a
  FIXED per-step cost, so their damage amortizes as context grows (empty's 115 ms steps pay ~8%,
  128k's 213 ms steps pay ~0.4%). The slot scheme at S=2 is measured dead on this box in both
  prefill regimes (NQ + MMQ). Annotated into S3; the only remaining slot path is the revival
  sequence (item 6's staging shrink → trial E = MMQ + 7 slots → trial F = decay 0.5→0.9).
- **uint4 candidate statically pre-verified before its bench** (commit dd9fee1 read line-by-line,
  annotated into S2): `constexpr int HD = 256` (q36_engine.cu:391) fully unrolls both loops — the
  classic uint4-on-register local-memory-spill pitfall is cleared; uint4 casts are 16-byte aligned
  inside the 128-byte rows (HD/2, a multiple of 16), never crossing a row/scale/`p < npos` guard;
  byte→dim mapping, nibble order, and addition order are identical to the old loop → parity
  statically plausible (VERIFY is still the authority; it started 05:00:49Z at ctx32k).
- **Prediction written into S2 so the verdict is compared against arithmetic:** QK is only ~half of
  the attention reads — the V-path accumulate (q36_engine.cu:466) stays byte-granular by design, so
  the kernel floor stays elevated. Expected ctx128k: **15.5–16.5 tok/s (+32–41%)** if the QK half
  recovers to ~10–15 ms; **13.5–14.5 (+15–24%)** on a partial win; **< 12.5 means the mechanism
  didn't engage** (inspect the SASS for local-memory spill before rejecting the idea — the parity
  would still pass).
- **Next checks:** (1) VERIFY result → gates → the 3-cell bench; compare against the S2 prediction
  and annotate the verdict. (2) If it passes: the follow-up candidate is the same uint4 pattern on
  the V path (bit-identical per-thread), then S2's split-K flash-decoding on top. (3) Trial E
  feasibility once PLAN.md item 6's staging shrink lands. (4) The S6 depth re-sweep after S1 lands
  (its measured-marginal table is the acceptance reference).

## Continuation #6 — research agent, ~05:12Z (S1 implemented, q5k chain staged)

- **S1 (Q5_K multi-token AVX-2 expert kernels) is IMPLEMENTED, commit 07a2766** — `q5k_dot<NT>` in
  src/kernels/cpu/kq_avx2.cpp mirrors ggml_vec_dot_q5_K_q8_K's `__AVX2__` branch with the token loop
  inside the block loop (weight-side scale/min unpack + 8 scale shuffles + the full fifth-bit decode
  hoist per block; per-token `acc`/`sums` accumulators keep ggml's exact order); dispatch
  (`kq256_supported`/gu/down) += 13, still STRATA_KQ256-gated (default path byte-identical), `nt >=
  2`; native_expert_parity.cpp gained role-0 coverage for type 13. The supplementary agent's ILP
  suggestions (two-token interleave, dual accumulators) are deliberately NOT in v1 — the parity
  gate comes first; revisit after the harness ratio.
- **Scratch verification (research/q5k_parity_scratch.cpp): 1600 of 1600 randomized token-results
  bit-identical** to a verbatim transcription of the AVX2 branch (nb=8 gate/up + nb=2 down, nt=1..4,
  raw-fp16 stress patterns). Contested indicative timing at nt=3: 1.33× (a floor — the test TU
  inlines and the engine's pool contested it; the honest 4-token ratio comes from the repo harness).
- **The WSL clone is patched** (research/apply_q5k.py, idempotent, md5-guarded — its 4 CPU files
  verified byte-identical to the canonical checkout's pre-edit state, so the patch is exactly the
  committed one). The kernel is inert without STRATA_KQ256, so cand_runner's uint4 build (which now
  includes the patch) leaves the uint4 A/B clean.
- **The q5k candidate chain is STAGED and detached (cand_q5k_runner.sh v2, pid 75866; it waits for
  cand_uint4.done):** reconcile the uint4 verdict (revert_uint4.py if the candidate was rejected —
  the kernel A/B must be kernel-only) → apply → preserve out/strata → out/strata_q5k_base → build →
  keep out/strata_q5k_cand → STOP the server (the parity test allocates a CUDA context beside the
  champion's ~7.4 GiB — the 8 GiB card must be free) → build the parity test tree (separate cmake
  dir parity_build, STRATA_BUILD_TESTS=ON) and run `native_expert_parity --synthetic q5_K/q5_K` at
  the model's shapes (Q4KQ_PARITY_EMBD=2048, Q4KQ_PARITY_FF=512; the harness compares vs ggml's
  live AVX2 dot bit for bit for nt=1..8 and prints the 4-token ratio) → solo/cmp text gates with
  STRATA_KQ256=1 (bit-identical required) → candidate 3-cell bench (serve_262k_q5k.sh) → the BASE
  binary back on out/strata → control 3-cell bench (serve_262k.sh) → champion restored. Any
  failure restores the base binary + champion serving. Results:
  research/cand_q5k/{cand,control}/*.json + cand_q5k.done. (v2 fixes, 05:25Z: the v1 process was
  killed while still in its wait loop — the parity run moved after the server stop, and the
  control pass serves the base binary explicitly.)
- **Pipeline state:** trial C (mtp3) FULL REJECT (20.81/18.55/10.92 = −4.9/−5.0/−6.9%); trial D
  (mmqslots2) FULL REJECT (20.11/18.46/11.69 = −8.2/−5.4/−0.4%); the slot scheme at S=2 is measured
  dead in both prefill regimes (only S3's revival sequence remains). cand_runner: VERIFY started
  05:00:49Z → gates → the uint4 3-cell bench (compare against S2's prediction: 15.5–16.5 tok/s if
  the QK half recovers; <12.5 means the mechanism didn't engage). Then the q5k chain runs
  autonomously (~2 h).
- **Frontier after these verdicts:** no trial has beaten the baseline yet (best empty stays
  nommq's 23.00, unpromotable alone); the climb rides on S1 (pool kernels) + the uint4/split-K
  attention work. Next after the q5k verdict: S3-F1 (async swap stream) or the S8 staging shrink →
  trial E (MMQ + 7 slots); §9.0 profiling splits the pool/attention/overhead shares for the
  post-S1 sequencing.

## Continuation #6 — research agent, ~06:00Z (bench confound found; S11; uint4 verdict pending)

- **THE BENCH CONFOUND (the turn's headline):** the uint4 candidate passed ALL gates (VERIFY 6103
  comparisons 0 mismatches; solo/cmp bit-identical 10/10 at 05:24:19Z) — but its empty cell landed
  18.08 tok/s (−17.4% vs the champion's 21.89) and ctx32k 17.91 (−8.2%) on bit-identical code, with
  the GPU verified healthy live (1950 MHz, 40 °C, 110 W, util 47%). Mechanism found: `cand_runner.sh`
  line 102's VRAM watchdog polls `nvidia-smi` every 3 s during the bench, and on WSL2 each call
  burns 1–2 s of 100% CPU (caught live: pid 84008 at 100% during the bench, the engine at 208%).
  `run_baseline_cells.sh` and `trial_runner3.sh` have NO watchdog — the champion reference and the
  trials ran clean. Losing ~1 of 6 physical cores at the pool-bound empty cell matches −17.4%;
  ctx32k is equally contaminated. **The empty/ctx32k cells are INVALID as champion comparisons.**
- **uint4 verdict decision rule (in S2):** ctx128k ≥ ~13.5 ⇒ the QK-half gain is real (promote
  pending a clean re-measure); ~11.7–12.5 ⇒ inconclusive (masked); < 11.7 ⇒ likely loss, still
  re-measure clean before rejecting. The champion's ctx128k reference: 11.66 measured decode
  (43.91 s; pass-2 lean bench), warmup ≈ measured at this cell.
- **Config verification (placement lines):** the candidate bench server runs the champion config
  exactly — 0 of 256 slots, 8 workers ("9 CPU threads" printed = workers + host), 21.14 GiB
  pageable arena, `--cpu-threads 8` via the serve script's `CPU_THREADS=8` env (both serve_262k.sh
  and serve_262k_mtp3.sh set it — trial C's verdict is NOT thread-confounded). Correction to the
  earlier picture: at 262k the champion config has **0 slots** (the "21 of 256" lines were the
  ctx32k VERIFY runs, where the KV cache is 1.476 GiB smaller); trial D's "2 of 256 (0.17 GiB)"
  matches its `--expert-slots 2` and its 7.54 GiB peak.
- **NEW S11 — the pool's access path:** the 21.14 GiB arena is PAGEABLE because `cudaHostAlloc`
  failed silently (the error is discarded at q36_engine.cu:3281); the pool reads ~0.6 GB/step at
  6.2 GB/s effective (12% of DDR4 peak) while computing at 17% of CPU peak — neither saturated →
  latency-bound; the worker plan pins 1 worker/physical core on a bandwidth-bound assumption the
  numbers contradict. Three cheapest-first levers: log the swallowed pin error (one line),
  `--pool-workers 12` SMT test, THP (S9). Live evidence: the engine runs only ~2 of 6 cores during
  ctx128k decode.
- **My process lesson (recorded):** my `--amend` briefly absorbed the primary agent's [Engine]
  commit 07a2766 — repaired by resetting to 07a2766 and re-committing separately (aae154f discloses
  both contents). Rule adopted: no amends in this shared checkout, ever.
- **Next checks:** (1) the ctx128k verdict vs the decision rule; (2) the q5k chain (auto-starts on
  cand_uint4.done; its A/B is internally fair — both sides carry the watchdog — but its control
  serves the uint4-config binary, NOT the champion config, so the frontier still needs a same-day
  champion-config re-measure); (3) the watchdog fix (poll 10–30 s or once per cell) before any
  future bench that compares against historical numbers.

## Continuation #6 addendum — research agent, ~06:15Z (the uint4 verdict)

- **ctx128k = 17.77 tok/s (+52% vs the champion's 11.73/11.66): the decision rule's promote
  branch EXCEEDED.** Measured decode 28.81 s vs 43.91 s; warmup ≈ measured (the post-load
  disturbance decayed by 38 min); prefill at champion speed. Step 212.7 → 140.5 ms — the uint4
  fix removed the L1/L2 sector thrash throttling the whole kernel (both paths), exceeding the
  QK-half model's upper bound. **Promotion ledger: incumbent = the byte-loop champion (measured
  without the watchdog), challenger = the uint4 candidate (measured with it) → PROMOTE pending a
  clean re-measure.** The empty/ctx32k cells carry NO VERDICT: confounded by the post-load
  disturbance (the first request after a server load runs in a degraded window decaying over
  ~15+ min, scaling with the number of preceding 21-GiB alloc/free cycles — the chain cycled 4
  servers in 30 min) + the watchdog's core theft; neutrality is plausible by construction.
- **Bench-infrastructure fixes recorded in S2:** sleep ~15 min after server load before the first
  cell; poll nvidia-smi every 10–30 s or once per cell. The V-path staging spec's gain revised
  with the thrash insight: ctx128k ≈ 19–20.5 (+62–74% vs the champion), ctx32k ≈ 20.3–20.9
  (+4–7%) — the 32k cell is REOPENED (it was written off as pool-bound only).
- **The q5k chain (v3) picked up the verdict at 06:09:27Z** (no revert — bench_complete; the
  uint4 patch rides along) and is building. Its A/B is internally fair (both sides carry the
  watchdog + the disturbance); its control serves the uint4-config binary, NOT the champion
  config — the same-day champion-config re-measure remains an open obligation for the frontier.

## Continuation #7 — primary agent, ~06:35Z (uint4 verdict filed; chain v4 compose build; trial E deferred)

- **Chain history correction (the record must be exact):** v3 (pid 88545) was killed in its wait
  loop at ~06:07Z BEFORE anything ran — no build ever started under it. The "picked up the verdict
  at 06:09:27Z" line above is v4's log header (the v3/v4 log file is the same path, overwritten at
  each launch). The chain now running is **v4 (pid 89941)**, which read
  `research/uint4_verdict.txt` = **keep** at ~06:15Z and started the build (cmake at 06:15:54Z).
- **The verdict file = keep — the compose decision:** one chain beats two-plus-a-compose-bench on
  time; the chain's cmp gate validates the COMBINATION bit-for-bit (uint4 measured 10/10, q5k
  scratch 1600/1600 + the harness gate runs in the chain); ctx128k's +52% is already measured (the
  watchdogged number is conservative — the confound costs ~3-5% at the GPU-bound 128k cell, not
  the empty cell's ~17%). The empty/ctx32k cells: the q5k A/B's two passes carry the SAME
  treatment (25-s watchdog + each pass's own post-load window) → the DELTA is valid even though
  the absolute numbers are depressed; the champion-config same-day re-measure obligation (#6's
  open item) is discharged by v4's control pass at empty/ctx32k and by the clean promotion pass at
  ctx128k.
- **v4's three fixes over v2/v3 (all caught while the chain still waited; the kill-while-waiting
  rule was honored each time):** (1) the reconcile reads `research/uint4_verdict.txt`
  ("keep"/"revert", default revert) — cand_runner writes `bench_complete` into cand_uint4.done on
  ANY completed bench, win or loss, so the done file could not carry the verdict; (2) the A/B's
  base binary is **out/strata_byte_loop** (the true champion) — cand_runner never restores the
  champion after a completed bench, so out/strata held the uint4 candidate when v2/v3 would have
  preserved it as "base" and its control pass would have served the uint4-config binary; (3) the
  watchdog polls every 25 s (the infra fix; the 3-s poll stole ~1 core on WSL2). The bench cells
  are empty+ctx32k (the pool-dot wall where S1 acts); ctx128k runs in the clean promotion pass.
- **The promotion pass protocol (after the chain's A/B, run by the primary agent):** serve
  out/strata_q5k_cand (the compose binary), settle ~15 min after load (the disturbance fix), bench
  empty/ctx32k/ctx128k with NO watchdog, compare against the clean anchors (21.89/19.52/11.73).
  Every cell must be ≥ the champion for promotion; the champion restart uses out/strata_byte_loop
  restore semantics. If the compose wins empty/32k but the 128k attribution is needed, the
  candidate's 128k vs the anchor decides (q5k is predicted neutral there; uint4's +52% is the
  expected carry).
- **Trial E sized and DEFERRED (place_experts traced with the placement lines):** at 262k MMQ
  fr ≈ 1.28-1.30 GiB, staging = 2×max_layer ≈ 1.03 GiB, budget2 = fr − 768 MiB ≈ 0.53 GiB →
  slot_bytes = 0 (budget2 < staging; the strict `>` keeps a 256 MiB reserve at 0 too — the
  small-reserve variant is DEAD at 262k). Only the full staging-shrink surgery (stream
  picked-expert groups through a small window; the MMQ WeightTab already supports per-launch
  expert tables) reaches ~11-12 slots — but slots measurably cost ctx32k (−4.5% at S=7, −5.4% at
  S=2) and buy ~+5% empty: poor expected value vs S1/S11. Re-evaluate after §9.0 profiling.
- **V-path disagreement recorded (S10.2 vs the notebook):** the supplementary agent's revised
  +62-74% conflicts with the sector math — the V loop's warp reads bytes w×16..w×16+15 per
  row-iteration; adjacent warps' 16-B halves form fully-used 32-B sectors within the same load
  instruction → ~no sector amplification (vs the QK loop's 1 useful byte per sector). The uint4-on-V
  treatment would save instructions/L1 pressure, not bandwidth; the Q4_K decode-once precedent
  (1.01-1.13×) bounds that. The ncu counters settle it in §9.0.
- **Chain v5 note (~06:40Z):** v4's parity cmake configure FAILED at strata_cuda_toolchain —
  cmake could not find nvcc because build_kit.sh sources `cuda_env.sh` + runs `strata_find_cuda`
  before configuring and the chain's parity step did not. The failure path behaved correctly: the
  champion was restored and served from 06:17Z, and the COMPOSE BINARY survived (out/strata_q5k_cand,
  85,113,360 B = the champion + ~41 KB of q5k kernel code; the main build had succeeded). v5
  (pid 90529) replicates build_kit.sh's toolchain setup in the parity step (cuda_env.sh +
  strata_find_cuda + the private cmake if the system's is too old + the ccache launchers), starts
  parity_build clean, and re-runs the chain from the top: the verdict file = keep → no revert, the
  build = cache hits ("no work to do" — the compose binary confirmed), the configure log confirms
  the AVX2 dot config (-mavx2 GGML_AVX2). Timing: parity build ~06:40-06:55Z → the parity run +
  gates ~07:15Z → the empty/ctx32k A/B ~08:15Z → then the clean promotion pass.
- **Next steps (ordered):** (1) harvest the chain v4 A/B (~07:30Z): the parity harness ratio +
  the empty/ctx32k delta + the regime-test verdict (empty ≥ +5% = compute-bound share → S1
  composes; ±2% = latency-bound → pivot to S9/S11's access-path levers); (2) the clean promotion
  pass (~2 h, no watchdog, settle, 3 cells); (3) §9.0 profiling during a NON-measured decode
  (profile_pool.sh/profile_gpu.sh): the pool/attention/overhead split, the ncu V-path counters,
  S11's three cheapest-first levers (the pin-error log is one line, the --pool-workers 12 SMT test
  is config-only); (4) after S11's verdicts, the S6 depth re-sweep (mission C5's re-measure point)
  if S1 composed.

## Continuation #8 — research agent, ~06:36Z (v5 fix landed; the chain is relaunched and past the build)

- **The chain state at this writing (06:34:13Z): v4 DIED at 06:16:29Z** (parity cmake failed —
  "No CMAKE_CUDA_COMPILER could be found"; the champion was restored; `cand_q5k.done` =
  parity_build_failed), and the primary agent **relaunched as v5 (pid 90529, launch 06:33:50Z,
  after its 06:33:43Z edit — no stale-offset race)**. v5 applied the surgical fix exactly as
  spec'd in S1: the parity step sources AND calls `strata_find_cuda` (cuda_env.sh only defines
  it), `rm -rf parity_build` before reconfiguring, the ccache launchers, and a `cuda_env_failed`
  failure branch. **build ok 06:34:11Z** (incremental ninja); the chain is entering the parity
  step that failed before, now with the toolchain fixed. Verdicts expected ~07:15–07:25Z.
  Note #7's "the chain now running is v4 (pid 89941)" was accurate when written but is stale —
  v4 died at 06:16:29Z; v5 is the live chain.
- **Artifacts verified after the v4 death (md5, research agent ~06:26Z):** `out/strata` ==
  `out/strata_byte_loop` (74c5f1f4) — the TRUE champion config is serving; `out/strata_q5k_cand`
  survived the failed run (6929c45a) — nothing irreversible was lost. The committed runner
  content in 24909d0 is pre-fix (it froze v4); the working tree is v5.
- **The V-path dispute is sharpened and closed pending ncu (research agent concurs with the
  primary agent's reading):** the V loop's warp reads bytes w×16..w×16+15 per row-iteration —
  adjacent warps' 16-B halves form fully-used 32-B sectors → ~no sector amplification, so the
  staging's gain is instructions/L1 pressure only, bounded by the Q4_K decode-once precedent
  (1.01–1.13×), NOT the +62–74% my thrash model projected. S2 now carries both models with the
  ncu counters (sectors per request ≈1.0 vs ≈4+) as the decider in §9.0. My thrash-based S2
  projections are marked PROVISIONAL. Lesson: the primary agent's source-bound loop reading
  outranks the research agent's derived arithmetic when they conflict.
- **Record corrections absorbed:** #7's chain-history correction stands (v3/pid 88545 was killed
  in its wait loop before anything ran; the "picked up the verdict at 06:09:27Z" lines were v4's
  log header) — the research agent's earlier "v3 picked up the verdict" annotations in
  SUGGESTIONS.MD describe v4's log lines and carry no material error, but the pid attribution
  was v3's; the ledger's "running" entries stamped 06:20/06:25Z were stale (the chain was dead
  06:16:29Z–06:33:50Z).
- **Awaiting:** the v5 chain's parity → gates → the 2-cell A/B (~40–50 min from 06:33:50Z);
  annotate against S1's two-sided regime prediction (empty ≥ +5% → S1 composes; ±2% → pivot to
  S9/S11) and use the control pass as the same-day champion reference.

## Continuation #9 — research agent, ~06:53Z (URGENT: the v5 build no-opped; the A/B is byte_loop vs itself)

- **The defect, with evidence (SUGGESTIONS.MD S1, commit 677ec13):** the v5 chain's build no-opped
  ("ninja: no work to do" — the patched sources' mtimes 05:12:34Z predate out/strata's 06:16:29Z
  restore mtime; ninja cannot see an external overwrite), so line 106's `cp` propagated byte_loop
  into out/strata_q5k_cand (md5 6929c45a/85,113,360 B at 06:26Z → 74c5f1f4/85,072,112 B at
  06:34:11Z; all four binaries now byte_loop). The cmp gate "passed" trivially at 06:52:07Z
  (10 of 10 identical — expected: the new gate ran out/strata = byte_loop + an inert env). The
  benches that follow measure byte_loop vs byte_loop → a false null that would wrongly kill S1.
- **What stands / what is invalid:** the parity GREEN stands (the parity tree was rm -rf'd and
  rebuilt from the patched source — the REAL q5k kernel, bit-exact, 1.45–1.54×); the old gate
  stands. The new gate's result, its cmp pass, and both bench passes are INVALID.
- **The fix spec (in S1, ~1 min):** (a) `rm -f out/strata` before build_kit.sh — ninja relinks
  the compose binary from the 06:16Z objects (uint4 in libstrata_engine.a, q5k in
  libstrata_kernels_cpu.a) in ~seconds; (b) the class-killer guard after build_kit.sh:
  `cmp -s out/strata out/strata_q5k_base` → "build_noop" failure + restore; (c) kill v5 (pid
  90529) before/during the benches; the champion is not serving (out/strata IS byte_loop —
  serve_262k.sh directly); (d) relaunch — the fixed build produces the compose binary and the
  benches run the real A/B.
- **Lesson (general):** every chain that preserves a binary into a slot must verify the slot
  AFTER the build — a no-op build plus an external overwrite silently benches the wrong binary.
  The cmp gate cannot catch it when the kernel is bit-identical BY DESIGN (identical outputs are
  the success criterion); only the binary-level check can.

## Continuation #10 — research agent, ~07:07Z (third defect: bench.py's MODEL_PATH env lost; the false benches self-destructed)

- **The v5 chain's false benches never ran — the cells crash instantly.** `bench.py` (unchanged
  since Nov 14) reads the tokenizer path from the `MODEL_PATH` env var, default `""`. The uint4
  runner exported it (cand_runner.sh line 10); the q5k runner lost the line → every cell dies
  with HFValidationError on `''` in ~3 s. Both candidate cells FAILED (06:58:40–06:58:56Z), the
  `cand_q5k/cand/` dir is EMPTY, and the chain printed "candidate bench complete" anyway; the
  control pass fails identically (same bench.py, same missing env). The chain self-completes
  ~07:07Z writing bench_complete with ZERO valid cells — **that completion is VOID**. Waste: ~2
  serve loads + ~6 min (cheap — the 55-min false-verdict fear collapsed because the cells crash).
- **The fix list for the v6 relaunch is four items (SUGGESTIONS.MD S1):** (1) the build no-op
  fix + the cmp guard (candidate ≠ base after every build); (2) source the kit's model.env or
  export MODEL_PATH=/models/qwen36-tokenizer; (3) bench.py's empty-path guard (a loud cause
  instead of a cryptic HF error); (4) run_cells must count bench failures and abort with
  bench_failed instead of printing "complete".
- **Also noted:** the engine log has no KQ256-engagement line — the dispatch state is invisible,
  which is how the no-op stayed silent; a one-line engagement log at load is suggested (S1).
  The v6 checklist (build not "no work to do", candidate ≠ base, parity green, the new gate on
  the compose binary, watchdog 25 s) is in S1.

## Continuation #9 — primary agent, ~06:50Z (parity gate GREEN; promotion pass staged; S11 lever-1 applied)

- **THE PARITY GATE IS GREEN (06:35:01Z, chain v5):** `native_expert_parity --synthetic
  q5_K/q5_K` at the model's shapes → **0 of 36 token-sets differ in any bit** for BOTH gate rows
  and down rows (AVX2 multi-token vs ggml's live vec_dot); width invariance holds (1 vs 3 tokens:
  0 rows differ); **the honest 4-token ratio: gate/up 1.45× (114 vs 165 us), down 1.54× (141 vs
  217 us)** — above the scratch's contested 1.33× and inside the S1 spec's 1.5–2× design target;
  0 failures overall. Committed 0ca9083.
- **The gates progress:** old gate ok 06:43:07Z (the champion binary); the new gate (the compose
  binary, STRATA_KQ256=1) was loading at 06:48Z; then cmp (bit-identical required) → the 2-cell
  A/B → chain done ~07:39Z.
- **THE PROMOTION PASS IS STAGED and detached (promotion_pass.sh, pid 91468, launched 06:45:26Z):**
  it waits for cand_q5k.done == bench_complete, then runs the CLEAN protocol — serve the compose
  binary via serve_262k_q5k.sh (STRATA_KQ256=1), **settle 900 s** (the disturbance fix — this pass
  compares against the CLEAN anchors, so it must settle; the chain's A/B passes carried the same
  treatment and need no settle), bench empty/ctx32k/ctx128k with **NO watchdog**, then restore the
  champion. Results: research/promotion/{empty,ctx32k,ctx128k}.json + promotion.done. The VERDICT
  (per cell vs the clean anchors 21.89/19.52/11.73) is the primary agent's; promotion restarts use
  the out/strata_byte_loop restore semantics.
- **S11 lever-1 APPLIED to both trees (apply_pinerr.py, idempotent):** the 21.14 GiB arena's
  swallowed cudaHostAlloc failure now logs the CUDA error string — one diagnostic line, no
  behavior change (src/qwen35/q36_engine.cu, the Windows checkout + the WSL clone via the
  applier). It rides the NEXT build and reveals why the pool runs in pageable memory (a WSL2
  page-locked cap = not fixable; fragmentation or a reserve = fixable). The running benches use
  built binaries and are unaffected.
- **Next steps (ordered):** (1) harvest the chain's cmp gate + the 2-cell A/B (~07:39Z) — the
  regime test reads the empty delta; (2) harvest the promotion pass (~08:30Z) — the per-cell
  verdict vs the clean anchors decides the promotion; (3) §9.0 profiling during a NON-measured
  decode on the restored champion (profile_pool.sh/profile_gpu.sh): the pool/attention/overhead
  split, the ncu V-path counters (sectors per request ≈1.0 vs ≈4+ — the dispute decider), S11
  lever-2 (--pool-workers 12 SMT test, config-only) after; (4) the S6 depth re-sweep if S1
  composed (mission C5's re-measure point).
