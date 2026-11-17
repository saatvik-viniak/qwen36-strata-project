# SUGGESTIONS.MD — proposals from the supplementary research agent

**Who wrote this:** I am an **additional AI agent whose sole purpose is deep research into kernel
optimization techniques from online papers, literature, and other repositories**, and to propose
changes to this engine's kernels by writing them into this file. I analyze the runtime evidence the
primary agent records (PROGRESS.md, research/hillclimb/, RESEARCH_HANDOFF.md) and propose; **I do not
build, bench, or push commits** — the primary agent acts on worthwhile items and annotates outcomes
back into this file. All my commits are signed as GLM 5.3 Flash (Maya-s quant), no co-author line,
per the repo's commit rule in auto-research.md.

**Protocol (agreed in RESEARCH_HANDOFF.md session #3, user rule 2):** the primary agent checks this
file briefly every ~15 min while an optimization runs, acts on worthwhile items, and annotates what
worked vs what hasn't back into the item's `Status:` line. I re-check the frontier every turn I am
run, prune items the evidence has made obsolete, and log my updates at the bottom.

**How to read each item:** `Change` (exact file/function), `Mechanism` (why, with the repo's own
measured numbers), `Measure` (the smallest decisive check), `Sources` (online evidence), `Status`.

---

## Frontier snapshot when this file was written

(2026-11-17 ~04:00Z, from git log + research/hillclimb/ledger.jsonl — so suggestions don't repeat.)

- Champion = 262k int4 baseline: empty 21.92 / ctx32k 19.52 (median) / ctx128k 11.80 decode tok/s;
  peaks 7.35–7.38 GiB. 2.00x targets: 43.85 / 37.87 / 23.60.
- Trial A (nommq, 7 slots) REJECT pending control; trial B (CT 5) REJECT (wash, −0.9/−1.0/−0.2%);
  trial C (mtp3) running, trial D (mmqslots2) queued via trial_runner3.sh.
- Candidate pending build+verify+bench: int4 attention QK read vectorized to `__ldg(uint4)`
  (commits dd9fee1/f367645) — the 128k cell's transaction-bound read, 16x fewer L1 transactions.
- Walls (research/hillclimb/THEORY.md): empty/32k are **pool-bound** — the CPU pool runs
  ~3.1 GMACs/verify-step at ~61 GFLOPS effective (~17% of the Zen-2 machine peak), ≈102 ms of the
  114.6 ms empty step; 128k adds the int4 attention kernel reading 0.738 GB/step at ~10 GB/s
  effective (byte-granular loads). 2x needs pool ≈12–13 GB/s effective and attention ≈100 GB/s.

---

## S1 — A Q5_K multi-token AVX2/FMA pool kernel (the empty/32k lever) — ADOPTED as PLAN.md item 7

**Status: ADOPTED (PLAN.md #7, pending); spec sharpened below.** ← annotate outcomes here.
*(Correction from my first draft: Q5_K is **type 13** in this fork's enum — the vendored
`third_party/strata-ggml/ggml/src/ggml-cuda-tq/include/ggml.h` has Q8_0=8, Q4_K=12, Q5_K=13,
Q6_K=14. My first draft said 14; PLAN.md's "type 13" is right.)*

- **Change:** `src/kernels/cpu/kq_avx2.cpp` + the dispatch in `src/kernels/cpu/native_expert.cpp`.
  The model's experts are Q5_K (gate/up type 13, down type 13). The dispatch covers Q4_K gate/up
  (`kq256_gu_rows`, `f.gu_type == 12`), Q5_1/Q8_0 down (`f.d_type == 7 || 8`), Q5_0 down
  (`q50_512_down_rows`, type 6), IQ4_NL, NVFP4 — **Q5_K hits none of them** and falls to ggml-cpu's
  single-token `vec_dot` singleton loop (native_expert.cpp lines ~620 and ~694). Extend the KQ256
  multi-token kernel family to type 13 for both gate/up and down.
- **The exact kernel to write** (from the vendored ggml-cpu's `ggml_vec_dot_q5_K_q8_K` AVX2 branch,
  `third_party/strata-ggml/ggml/src/ggml-cpu/arch/x86/quants.c` lines 2216–2310 — the same source
  kq_avx2.cpp already mirrors for Q4_K): per 256-value block, hoist out of the token loop everything
  that depends only on the weights: the `utmp` scale/min unpacking (kmask1/2/3 chain) +
  `_mm256_cvtepu8_epi16` (mins_and_scales), the 8 scale shuffles (`get_scale_shuffle_k4(2j)`,
  `2j+1`), and — the Q5_K-specific prize — **the full 5-bit decode**: `q5l` (nibble `and`/unpack) +
  `q5h` (the `hbits`/`hmask` shift chain, 6 ops per 32-value pair) + the `q5l+q5h` adds → 8
  `__m256i` of decoded 5-bit values per block. What stays per token (in ggml's exact order, for
  bit-exactness): the 2 `maddubs` + 2 `madd` + 1 `add` per j-pair, the q8 loads, the `summs` chain
  (`bsums` madd, `dmin` scalar), and the `acc = fmadd(vd, cvtepi32(sumi), acc)` tail (one acc per
  token).
- **Why Q5_K pays when Q4_K's decode-once did not:** Q4_K's per-token weight-side work is only the
  nibble unpack + scale shuffles (~40% of its integer ops — and STRATA_KQ256 measured just
  1.01–1.13x, native_expert.cpp lines 552–553). Q5_K adds the heavy fifth-bit chain: ~16 of ~21
  integer ops per pair are weight-side, so decode-once cuts the per-token integer work to the
  ~5-op maddubs/madd/add core. Design target ~1.5–2x on the dot alone — **measure that first** in
  `bench/micro/kq_cpu_bench.cpp` before any engine A/B; the Q4_K precedent is the caution, and the
  2x empty target needs ~2.6x on the pool, so expect this to be a milestone lever that composes
  with S3/S4, not the whole climb.
- **ILP beyond decode-once** (the part that must beat the Q4_K precedent): interleave two tokens
  per j-iteration (same decoded q5 vectors serve both tokens' q8 loads → doubles maddubs/madd per
  q5 fetch), and alternate two accumulators per token to break the `add`-to-`sumi` dependency.
- **Dispatch:** gate/up `kq && (f.gu_type == 12 || f.gu_type == 13)`; down `f.d_type == 7 || 8 ||
  13` (new Q5_K down-rows kernel — today down type 13 has no native kernel at all). Keep the
  STRATA_KQ256 gate, `nt >= 2`, and the #152 rule for WindowInvariant arithmetic, as the Q4_K path
  does.
- **Measure:** kq_cpu_bench (dot alone) → bit-exact parity (native_expert_parity, ggml's exact
  integer chain per token) → STRATA_KQ256=1 empty cell A/B (promotion rule: ≥2% median win, no
  cell regressing >2%).
- **Sources:** ik_llama.cpp README (3.27x PP on AVX2; reworked AVX2 i-quant kernels incl. IQ5_K,
  PR 427): <https://github.com/ikawrakow/ik_llama.cpp/pull/427>; llama.cpp issue #30342 (~7% CPU
  MoE decode swing from a single Clang `vpinsrw` change — single-instruction details matter):
  <https://github.com/ggml-org/llama.cpp/issues/30342>; llama.cpp "persistent expert slot pool"
  discussion: <https://github.com/ggml-org/llama.cpp/discussions/28248>.

## S2 — Split-K flash-decoding attention with fused int4 dequant (the 128k lever)

**Status: PROPOSED** (sequenced AFTER the pending uint4 QK-read candidate is measured — one problem
per change).

- **Change:** `src/qwen35/q36_engine.cu` `k_attn_part` (int4 branch). Today one CTA per KV head scans
  0.738 GB/step serially. Split each head's 128k-cell range into 8–16 slices; each computes a partial
  online-softmax (m, l, acc) over its slice; a tiny second kernel merges the partials per head —
  flash-decoding. Fuse the int4 dequant into the QK dot (uint4 loads → `__byte_perm`/`lop3` unpack →
  `__half2` dot, fp32 accumulate) so no float/half window is materialized; `cp.async` double-buffer
  2–4 KB tiles to hide DRAM latency (sm_86 supports cp.async).
- **Mechanism:** the attention kernel runs 45–57x above the 448 GB/s DRAM floor — it is
  latency/transaction-bound at one CTA per head, and 2 KV heads × 262k cells is exactly the regime
  flash-decoding was built for. The ceiling says 128k 2x needs ~100 GB/s effective from ~10.
- **Measure:** nsys/ncu kernel time for `k_attn_part` at ctx128k before/after (§9.0 scripts exist),
  then the 3-cell bench. Parity: STRATA_Q36_VERIFY=1 + the gates; the pending uint4 candidate's
  bit-identical construction is the template.
- **Sources:** Flash-Decoding (Stanford CRFM, the 3-step split-KV + online-softmax reduction design):
  <https://crfm.stanford.edu/2023/10/12/flashdecoding.html>; FlashInfer (arXiv 2501.01005, block-sparse
  KV formats + split-KV decode): <https://arxiv.org/pdf/2501.01005>; llama.cpp's flash-decoding
  implementation: <https://github.com/ggml-org/llama.cpp/commit/d5062b24c107165a1ff9af22339428ecb7758a4b>;
  int4-KV-fused decode attention measured outrunning fp16 by moving 3.2–3.5x fewer bytes (KIVI-style
  fused int4 cache): <https://arxiv.org/html/2605.05699v1>.
- **Implementation sketch (added ~04:20Z, composes with the pending uint4 candidate):** per
  (layer, kv_head, slice) CTA: slice the cell range into 8–16 slices — at ctx128k one slice of 16k
  cells is ~2.1 MB of packed K per CTA; one CTA cannot hide 1.4 GB of KV latency, but 11 layers ×
  2 KV heads × 8 slices = **176 CTAs** is enough parallelism to pull ~100+ GB/s from a 448 GB/s
  card. Each CTA computes a partial online-softmax (m, l, acc[256 fp32]) over its slice with the
  uint4 candidate's `__ldg(uint4)` read + fused dequant as the inner loop, double-buffering 2–4 KB
  packed tiles with `cp.async`; a small merge kernel reduces the S partials per q-head (GQA: 16
  q-heads over 2 KV heads → 8 q-heads share a KV head). Scratch: 16 × 8 × 258 fp32 ≈ 132 KB.
  **Verification-contract note:** split-K changes the softmax reduction order, so the result is NOT
  bit-identical to the old kernel — the parity gate must be the tolerance form the mission already
  allows ("per-kernel counts and magnitude where rounding legitimately differs"), plus greedy text
  parity vs the fp32 reference at 32k and needle correctness at 128k. Do not carry the uint4
  candidate's bit-identical claim onto this kernel.
- **External precedent for reading quantized KV in place** (researched ~04:20Z): llama.cpp has
  shipped quantized-KV flash-attention CUDA kernels since PR #7527 (q4_0/q5_0/q5_1/q8_0 K/V read
  and dequantized in-kernel; "quantizing K makes the performance slightly better"), its
  vector-kernel refactor PR #16208 decouples threads from head size specifically to support
  **head dim 256** with a quantized KV (our head_dim), and the 2026 MMA-path work (ggml-org PR
  #31802; unslothai PR #303) dequantizes q4_0/q8_0 K/V **tiles as they load** on Ampere+ — the
  same fused-dequant pattern as the uint4 candidate, measured +8–20% tok/s with KLD-0 validation.
  The Metal path's separate dequant-to-f16 pass (PR #27390 style) is the shape to avoid: it
  materializes a full f16 window every step, which mission A7 explicitly rejects.

## S3 — Make the slot mechanism non-blocking (compose trial A's +5.1% empty without its 32k loss)

**Status: PROPOSED** (the primary agent's composition recipe in RESEARCH_HANDOFF.md #3 — here are
the literature-backed options to fix the churn).

- **Change:** `src/qwen35/q36_engine.cu` — the rebalance (line 2583) and its sync. Three graduated
  options, cheapest first, all composable with the MMQ staging shrink (PLAN.md item 6):
  1. **Make the rebalance non-blocking (F1):** the swaps already run on the engine's stream
     (`cudaMemcpyAsync(..., st)`, line 2616), but line 2629 ends with an **unconditional**
     `cudaStreamSynchronize(st)` — it stalls even with zero swaps, and its own comment states why:
     `H.slot_of`'s host copy is pageable ("the upload is done before it changes"). Fix: pinned
     double-buffered slot_of host memory (two buffers; CPU writes the one not in flight), a
     dedicated swap stream, and a `cudaStreamWaitEvent` on the decode stream instead of the full
     sync; make the sync conditional on `changed`.
  2. **CPU fallback for misses (F2, HybriMoE):** on a router miss (expert not slotted), route that
     expert's rows to the CPU pool batch — which already computes the other misses — instead
     of swapping it in; promote only the score-selected top-S at rebalance boundaries. Kills the
     swap stall AND the churn; trial A's empty hit-saving is preserved.
  3. **Weaker decay / context-scaled cadence (F3):** line 2627 halves all 256 scores every 32 rows
     (`v *= 0.5`) — an expert unused for ~32 rows falls under the residents and ping-pongs, which
     is trial A's 32k mechanism. Try ×0.9, or `kRebalanceEvery` 32 → 64/128 scaled with context, or
     freeze the decay during prompts.
- **Trial D decision tree (mmqslots2, running when this was written):** win on empty with no ctx32k
  regression → promote slots+MMQ as champion, then F3/F1 to scale slots up (the staging shrink
  frees VRAM for 7 slots). Wash or ctx32k loss → slots at the VRAM edge don't pay at S=2, and
  F3 → F2 is the path to make trial A's 7-slot empty win survive 32k.
- **Mechanism:** trial A proved 7 slots help empty (+5.1%) but the blocking swaps cost 32k (−4.5%).
  Remove the stall and the composition (MMQ staging shrink ~4x → more slots + fast MMQ prefill) is
  the single largest decode lever for both empty and 32k.
- **Measure:** trial D (mmqslots2) is the cheap sign test already queued; then the above, one at a
  time, at ctx32k first (the churn-sensitive cell).
- **Sources:** HybriMoE (arXiv 2504.05897 — hybrid CPU-GPU scheduling; **CPU executes the expert
  layer when it is not in the GPU cache**, plus impact-driven prefetching):
  <https://arxiv.org/pdf/2504.05897.pdf>; MoE-CORE (arXiv 2610.01950 — coordinated offload/residency
  under memory constraints): <https://arxiv.org/pdf/2610.01950>; Fiddler (ICLR'25 — utilization-based
  CPU/GPU expert allocation at local devices): <https://github.com/efeslab/fiddler>.

## S4 — Prefetch the next layer's experts on a second stream (mission B3, literature-strong)

**Status: PROPOSED** (composes with S3; independent of slot count).

- **Change:** the router of layer L is computed before layer L's expert GEMM — issue async H2D for
  the top experts of L+1 while attention/GDN of L still runs (second stream, pinned host staging,
  per-layer events). No overlap of dependent work; only the independent halves move.
- **Mechanism:** PCIe-bound expert movement is the pool's structural cost at 262k (MMQ prefill
  streams 21.14 GiB per chunk at ~5.4 GB/s effective). Pre-gated MoE's MoE-Prefetch system shows
  pre-gating (predicting the next layer's loads from the current one) hides 30–60% of copy time;
  Fiddler and MoE-CORE reach the same conclusion from placement.
- **Measure:** decode tps + the engine log's copy-time accounting at empty and ctx32k; the 30-min
  budget rule applies (skip ctx128k prefill variants).
- **Sources:** Pre-gated MoE (arXiv 2308.12066, MSR — algorithm-system co-design, MoE-OnDemand and
  MoE-Prefetch): <https://arxiv.org/html/2308.12066v3>; fMoE (arXiv 2502.05370 — fine-grained expert
  offloading): <https://www.alphaxiv.org/abs/2502.05370v1>.

## S5 — Pin hot experts by router frequency (mission B2)

**Status: PROPOSED** (after S3/S4; needs the router-choice counter to exist).

- **Change:** count router choices over a 512-token decode (device-side histogram or a CPU counter
  in the router path), pin the top-K experts per layer in the VRAM slots, LRU the rest (the slot
  tables `hk`/`hv` already support per-expert placement). PowerInver-style hot/cold split.
- **Mechanism:** if the router has temporal locality (llama.cpp's two-tier GPU+RAM expert cache and
  n-cpu-moe tuning guides both exploit this), the pinned set's hit rate cuts both swaps and PCIe.
  MoE-Offloading formalizes the same hierarchy (GPU → CPU → NVMe).
- **Measure:** hit rate + decode tps at ctx32k; peak VRAM guard 7.9 GiB.
- **Sources:** llama.cpp two-tier GPU+RAM expert cache discussion:
  <https://github.com/ggml-org/llama.cpp/issues/20757>; n-cpu-moe tuning (what slots actually buy):
  <https://partnerinai.com/blogs/llamacpp-n-cpu-moe-performance-why-speedups-happen>; PowerInfer /
  MoE-Offloading lineage via MoE-CORE above.

## S6 — Tree drafting on the MTP block (raise tokens/step without linear verify cost)

**Status: PROPOSED — trial C's verdict confirms the direction** (research agent, ~04:10Z: mtp3
empty 20.81 (−5.1%), ctx32k 18.55 (−5.0% vs 19.52); ctx128k was running — chain depth 3 pays 3
sequential draft steps for less acceptance than it costs; a tree gets more candidates per
sequential step. The model's hybrid structure is the best case for it).

- **Change:** draft a 2–3-token tree per step (the MTP block + greedy top-2 branches), verify all
  branches in ONE pass with a tree attention mask in `k_attn_part` (the verify path already batches
  rows: `rs.kc`/`rs.vc`). EAGLE-2 is the reference design; Twig argues tree speculation specifically
  suits **hybrid-attention (SSM/GDN + attention) LLMs** because the idle GDN headroom absorbs the
  extra verify rows.
- **Mechanism:** acceptance is context-dependent (EAGLE-2's core finding; the repo measured a=2.51 at
  empty with MTP 2). A tree of depth 2–3 with 2 branches raises expected accepted tokens per verify
  step from ~2.5 toward 3–4 at the same verify cost per row-batch — the pool's per-step cost scales
  with rows, so tokens/step is nearly free until rows grow.
- **Measure:** tokens/step and acceptance, not just tok/s (mission C5); parity by construction
  (greedy verify). Budget: 30-min rule.
- **Sources:** EAGLE-2 (arXiv 2406.16858 — context-aware dynamic draft trees, 4–5.5 tokens/cycle):
  <https://arxiv.org/html/2406.16858v1>; Twig (arXiv 2608.01651 — tree speculative decoding for
  hybrid-attention LLMs): <https://arxiv.org/pdf/2608.01651>; SGLang MTP spec-decoding config surface:
  <https://docs.sglang.ai/advanced_features/speculative_decoding.html>.

## S7 — L2 persistence for the KV scales (small; only after S2)

**Status: PROPOSED** (parked until the split-K attention exists).

- **Change:** `cudaStreamSetAttribute(..., cudaStreamAttributeAccessPolicyWindow, ...)` with
  `hitProp=cudaAccessPropertyPersisting` on the current layer's scale region (one `__half` per
  (kv_head, cell-group) — tiny), reset per layer; sm_86 honors persisting L2.
- **Mechanism:** 4 MB L2; the scales are re-read by every slice in a split-K layout, so pinning them
  removes a redundant global pass per slice. Do NOT pin payload rows (the cache is 1.4 GB, L2 is 4 MB).
- **Measure:** L2 hit rate in ncu + kernel ms at ctx128k; the acceptance rule (≥2% cell win).
- **Source:** NVIDIA CUDA Programming Guide, L2 Cache Control (access policy windows; note the
  persistence-after-use caveat):
  <https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/l2-cache-control.html>.

## S8 — Prefill: MMQ staging shrink first, then int8 prefill GEMMs as a labelled trade

**Status: PROPOSED** (the staging shrink is already the primary agent's composition recipe — keep it;
the int8 trade is opt-in and lossy-labelled).

- **Change:** (a) shrink the MMQ staging sub-chunks ~4x in `place_experts`/the staging path so slots
  coexist with the fast MMQ prefill (same PCIe bytes, finer pipelining). (b) Opt-in int8 prefill
  GEMMs in a Hadamard-rotated domain for the dense/GDN projections — per-row scales suffice after
  rotation; decode stays bit-exact.
- **Mechanism:** MMQ prefill streams the whole 21.14 GiB pool per 1024-token chunk at ~5.4 GB/s
  effective (240–280 tok/s measured) — the staging shrink improves pipelining, not bytes. The int8
  trade's precedent: 1.89x GEMM speedup with NLL +0.17%, decode bit-exact (skill lever evidence).
- **Measure:** prefill tps + TTFT at ctx32k (the 128k prefill alone exceeds the 30-min budget rule —
  skip or slot context down per user rule 1).
- **Source:** inference-optimisation skill `references/levers.md` (int8/fp8 prefill GEMMs as a
  labelled lossy trade; grouped MoE padding cliffs).

## S9 — THP / MADV_HUGEPAGE on the 21.14 GiB pool arena

**Status: PROPOSED** (already queued by the primary agent — keep, with a caveat).

- **Change:** `madvise(MADV_HUGEPAGE)` on the pool arena (currently 0 anon hugepages on 4k pages;
  THP `madvise` mode). Caveat from the handoff: RAM runs at 24/25 GiB used — hugepage rounding can
  inflate RSS; measure `free -m` together with nvidia-smi as the handoff prescribes.
- **Mechanism:** the pool's 4k-page TLB pressure on a 22 GB arena is a plausible part of the ~8 ms
  step overhead; ik_llama.cpp/llama.cpp both tune MADV_WILLNEED/HUGEPAGE on large mmaps.
- **Measure:** pool time per step (engine log accounting) before/after at empty; RAM guard <24 GiB.

## S10 — Post-profiling items (do §9.0 first; these are where the profiler should point)

**Status: PROPOSED** (ordered by the ceiling math, cheapest checks first).

1. **Overhead split (~8 ms/step, 7% of empty):** PLAN.md's wall 3 now states CUDA graphs are
   **disabled in hybrid mode** — the captured graphs cover the GPU half, so the 41-layer × pool-call
   structure still pays per-step launch/sync tax. Measure first (nsys timeline: launch count, gaps),
   then one sync per token (C6) and fused norm/rope (C2) only where the timeline shows gaps.
2. **V-path byte loads in the int4 attention** (the pending uint4 candidate deliberately left the
   V-path untouched — one problem per change). Same vectorized-load treatment, after the QK read is
   measured.
3. **GDN chunk kernels:** 30 of 41 blocks are GDN; `bench/gdn_chunk_bench.cpp` and
   docs/GDN_CONTRACT.md exist. ik_llama.cpp ships a **fused delta-net for Qwen3-Next/Qwen3.5-MoE**
   (their PR list) — port ideas if the profiler shows GDN scan time matters.
4. **Tensor-core attention (A8):** dequant int4→f16 in shared memory, `mma.sync m16n8k16` for QK^T
   and PV with fp32 accumulation; only if the SIMT split-K path still leaves headroom after S2.

---

## Already present (do NOT propose these again)

- CUDA graph capture + replay for decode/verify/MTP (`g1`, `gv[]`, `gm1` in q36_engine.cu;
  `--no-graph` is the parity escape).
- Multi-token AVX2 kernels for Q4_K gate/up (KQ256), Q8_0/Q8_1 down, Q5_0 down (512-bit), IQ4_NL,
  NVFP4 (512/256-bit), TQ trellis types — S1 extends this family to Q5_K, it does not start it.
- Fused gate/up + SiLU rows (`iq512_fused_gu_rows` et al.), fused int4 KV dequant in the QK read
  (candidate), greedy sampler engaged (MTP drafting active), int4 KV cache landed + verified.

## Negative results to respect (do not rediscover)

- KQ256 multi-token kernel on Q4_K gate/up: 1.01–1.13x only — weights are L1-resident across
  ggml's per-token calls; the win must come from a faster dot, not decode-once.
- CT 5: a wash on every cell (−0.9/−1.0/−0.2%); CT 8 stays.
- LUT-codebook decode: 4x slower than ALU decode on Intel Xe (skill levers) — prefer bitplane/madd.
- Trial A (nommq): empty +5.1% but ctx32k −4.5% and prefill 3.4x slower — slot churn + native
  prefill cost; composition must fix both, not cherry-pick empty.
- int8 KV at 262k does not fit with the model (2.75 GiB); int4 is the only 262k path on this card.
- Never edit a running script mid-flight (the 03:30Z runner2 death); never push from my side.

## Sources (read this turn)

- Flash-Decoding: <https://crfm.stanford.edu/2023/10/12/flashdecoding.html>
- FlashInfer: <https://arxiv.org/pdf/2501.01005>
- llama.cpp flash-decoding: <https://github.com/ggml-org/llama.cpp/commit/d5062b24c107165a1ff9af22339428ecb7758a4b>
- KIVI (2-bit KV): <https://arxiv.org/pdf/2402.02750v1> · KVQuant: <https://www.alphaxiv.org/abs/2401.18079>
- Fused int4-KV decode attention: <https://arxiv.org/html/2605.05699v1>
- Pre-gated MoE: <https://arxiv.org/html/2308.12066v3> · HybriMoE: <https://arxiv.org/pdf/2504.05897.pdf>
- MoE-CORE: <https://arxiv.org/pdf/2610.01950> · Fiddler: <https://github.com/efeslab/fiddler>
- fMoE: <https://www.alphaxiv.org/abs/2502.05370v1>
- EAGLE-2: <https://arxiv.org/html/2406.16858v1> · Twig: <https://arxiv.org/pdf/2608.01651>
- ik_llama.cpp (AVX2 k-quants, fused MoE/delta-net): <https://github.com/ikawrakow/ik_llama.cpp>
- llama.cpp CPU-dot sensitivity: <https://github.com/ggml-org/llama.cpp/issues/30342>
- llama.cpp two-tier expert cache: <https://github.com/ggml-org/llama.cpp/issues/20757>
- n-cpu-moe tuning: <https://partnerinai.com/blogs/llamacpp-n-cpu-moe-performance-why-speedups-happen>
- CUDA L2 control: <https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/l2-cache-control.html>
- SGLang CUDA-graph speedup ranges: <https://sgl-project-sglang-93.mintlify.app/optimization/cuda-graph>

---
*(Update log appended below by the research agent, each entry signed.)*

## Update log

- **2026-11-17 ~04:15Z — first file created (commit ad4ef96).** Frontier read: ledger + git log +
  trial JSONs. Added S1–S10, the already-present list, the negative-results list, sources. Signed:
  GLM 5.3 Flash (Maya-s quant), additional AI agent (sole purpose: external kernel-optimization
  research and proposals).
- **2026-11-17 ~04:20Z — trial C partial check (commit 141e6f1).** research/trials/mtp3/empty.json:
  20.81 tok/s (−5.1% vs 21.92). Annotated S6: chain MTP 3 washes out at empty; the tree mechanism in
  S6 is the direction that gains acceptance without the sequential depth cost. Next checks: ctx32k +
  mtp3 verdict, then runner3's trial D (mmqslots2) and the uint4 candidate's build/bench results —
  S2's sequencing depends on the uint4 outcome, S3's options on trial D's churn sign.
- **2026-11-17 ~04:35Z — S1 sharpened + trial C verdict annotated (commit 2a70ddf).** (1) The primary
  agent ADOPTED S1 as research/hillclimb/PLAN.md item 7 ("pending") — I corrected S1's type number
  (Q5_K = **13** in this fork's enum, verified in third_party/strata-ggml/ggml/src/
  ggml-cuda-tq/include/ggml.h; my first draft said 14) and replaced the sketch with the exact
  kernel spec read from the vendored ggml_vec_dot_q5_K_q8_K AVX2 branch (what hoists per block, what
  stays per token, the two-token interleave + dual accumulators for ILP, kq_cpu_bench first, honest
  1.5–2x design target that composes rather than reaches 2x alone). (2) Trial C now has empty −5.1%
  AND ctx32k −5.0% (18.55) — annotated into S6; ctx128k was still running. (3) S10's overhead item
  refined with PLAN.md's wall 3: graphs are disabled in hybrid mode, so the launch/sync tax is real.
  Live queue: mtp3/ctx128k running (03:56Z) → trial D (mmqslots2) → champion restore → cand_runner
  builds + verifies + benches the uint4 candidate (S2's sequencing follows those verdicts).
- **2026-11-17 ~04:45Z — S2 and S3 sharpened (this commit), path question answered.** The user asked
  where this file lives: `C:\Users\Admin\Auto-research-agent\Runtime\projects\saatvik-viniak\qwen36-strata-project\SUGGESTIONS.MD`
  (repo root, branch main, committed locally, never pushed). New content: (1) S2 gained an
  implementation sketch (8–16 slices → 176 CTAs at ctx128k ≈ 2.1 MB packed K per CTA; partial
  online-softmax + merge; 132 KB scratch; cp.async double-buffer) and a **verification-contract
  note** — split-K changes the softmax reduction order, so bit-identity does NOT carry over from the
  uint4 candidate; the gate must be the mission's tolerance form + greedy text parity. Added the
  external precedent: llama.cpp has shipped in-kernel-dequant quantized-KV FA kernels since PR
  #7527, its PR #16208 decouples threads from head size specifically for head dim 256, and the 2026
  MMA work (ggml-org #31802, unslothai #303) dequantizes K/V tiles as they load (+8–20% tok/s,
  KLD-0). (2) S3's three options now carry exact code anchors: the swaps run on the engine's stream
  with an UNCONDITIONAL `cudaStreamSynchronize(st)` at line 2629 (stalls even with zero swaps;
  pageable slot_of is the stated reason — pinned double-buffer fixes it), the ×0.5 score decay at
  line 2627 (the ping-pong mechanism), and the HybriMoE CPU-fallback for misses. Added the trial D
  decision tree. Pipeline state at writing: mtp3/ctx128k landed ~04:18Z expected; trial D next;
  uint4 chain ~05:45Z.
