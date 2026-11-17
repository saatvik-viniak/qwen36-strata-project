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

## S1 — A Q5_K multi-token AVX2/FMA pool kernel (the empty/32k lever)

**Status: PROPOSED** ← annotate outcomes here.

- **Change:** `src/kernels/cpu/kq_avx2.cpp` + the dispatch in `src/kernels/cpu/native_expert.cpp`.
  The model's experts are Q5_K (gate/up type 14, down type 14). The dispatch covers Q4_K gate/up
  (`kq256_gu_rows`, `f.gu_type == 12`), Q8_0/Q8_1 down (`f.d_type == 7 || 8`), Q5_0 down
  (`q50_512_down_rows`), IQ4_NL, NVFP4 — **Q5_K hits none of them** and falls to ggml-cpu's
  single-token `vec_dot` singleton loop (native_expert.cpp lines ~620 and ~694). Extend the KQ256
  multi-token kernel to type 14 for both gate/up and down (Q5_K's K-quant block differs from Q4_K
  only by the 5th-bit mask `qm`; decode once per window, dot with the Q8_0/Q8_K activations via
  `_mm256_madd_epi16` accumulation in int32, fp32-reduce in the same order ggml's dot does).
- **Mechanism:** THEORY.md puts the pool at ~61 GFLOPS effective — the dot is compute-bound, not
  stream-bound (reads are only ~14 ms/step at 44 GB/s STREAM). The ceiling table says empty/32k 2x
  needs the pool at 12–13 GB/s effective, i.e. the dot ~2.5–3x faster. Precedents in-repo: the
  NVFP4-256 kernel measured **2.0–2.4x over ggml-cpu's dot at 4–8 tokens** (nvfp4_avx512_parity);
  ik_llama.cpp's rewritten AVX2 k-quant kernels give up to **3.27x prompt-processing speedup over
  upstream llama.cpp on AVX2 hardware** (their headline result) and they specifically reworked
  IQ/Q5_K-class AVX2 dots (ik PR 427). The win must come from a **faster dot + decode-once**, not
  decode-once alone — see the negative result below.
- **Respect the negative result:** STRATA_KQ256 for Q4_K gate/up measured only 1.01–1.13x
  (native_expert.cpp comment, lines 552–553): weights stay L1-resident across ggml's per-token calls,
  so decode-once alone doesn't pay. Target the **dot's ILP** (bitplane unpack like q2_avx, or
  int16-madd lanes), and cover the **down rows**, which for Q5_K have no native kernel at all.
- **Measure:** `bench/micro/kq_cpu_bench.cpp` (exists) for the dot alone, then one cell
  (empty first: a ≥2% median win with no cell regressing >2% per the promotion rule). Parity:
  bit-exact vs ggml's dot via the existing native_expert parity harnesses before any bench.
- **Sources:** ik_llama.cpp README (3.27x PP on AVX2; fused MoE ops; IQ5_K AVX2 fix, PR 427):
  <https://github.com/ikawrakow/ik_llama.cpp>; llama.cpp issue #30342 (~7% CPU MoE decode swing from
  a single Clang `vpinsrw` change — single-instruction details matter at this scale):
  <https://github.com/ggml-org/llama.cpp/issues/30342>; llama.cpp "persistent expert slot pool" and
  n-cpu-moe tuning guides (CPU-side MoE is a known, tuned path there):
  <https://github.com/ggml-org/llama.cpp/discussions/28248>.

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

## S3 — Make the slot mechanism non-blocking (compose trial A's +5.1% empty without its 32k loss)

**Status: PROPOSED** (the primary agent's composition recipe in RESEARCH_HANDOFF.md #3 — here are
the literature-backed options to fix the churn).

- **Change:** `src/qwen35/q36_engine.cu` slot rebalance + swap sites (`cudaMemcpy2DAsync`).
  Today a rebalance every 32 rows does ≤8 blocking 2.06 MB H2D copies + a sync (~2–3 ms/step at 7
  slots) — trial A's 32k cost. Three graduated options, cheapest first:
  1. **Async swap stream:** issue the swaps on a second stream with an event the decode waits on only
     at the use point; overlap with the attention kernel of the same step.
  2. **CPU fallback execution (HybriMoE):** when an expert is not in its slot, run that expert's
     rows on the CPU pool instead of blocking on a swap — the swap is then advisory, not a stall.
  3. **Context-scaled rebalance:** `kRebalanceEvery` scales with context (32k churns much more per
     step than empty); weaker decay or score-hysteresis avoids the ping-pong the 32k cell showed.
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

**Status: PROPOSED — trial C's partial verdict strengthens it** (research agent, ~04:15Z:
mtp3/empty.json = 20.81 tok/s, −5.1% vs 21.92 — chain depth 3 pays 3 sequential draft steps for
less acceptance than it costs; a tree gets more candidates per sequential step. The model's hybrid
structure is the best case for it).

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

1. **Overhead split (~8 ms/step, 7% of empty):** one sync per token (C6), sampler location, launch
   gaps under the captured graphs. Measure before changing anything (nsys timeline).
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
- **2026-11-17 ~04:20Z — trial C partial check (commit pending).** research/trials/mtp3/empty.json:
  20.81 tok/s (−5.1% vs 21.92). Annotated S6: chain MTP 3 washes out at empty; the tree mechanism in
  S6 is the direction that gains acceptance without the sequential depth cost. Next checks: ctx32k +
  mtp3 verdict, then runner3's trial D (mmqslots2) and the uint4 candidate's build/bench results —
  S2's sequencing depends on the uint4 outcome, S3's options on trial D's churn sign.
