# THEORY.md — ceilings for Qwen3.6-35B-A3B (Q5_K_S heretic) on the RTX 3070 8 GB rig

Model + hardware numbers measured or ground-truth-sourced; derived numbers are marked.

## Machine (to be re-measured, §"unmeasured")
- GPU: RTX 3070 8 GB, sm_86. Spec VRAM bandwidth 448 GB/s. **Device-copy bandwidth: not measured yet.**
- Host RAM: DDR4, WSL2 VM capped 26 GB (`.wslconfig`), Ryzen 5 3600X (6 cores / 12 threads).
- **RAM stream bandwidth: not measured yet.** Effective pool read rate derived below (~6 GB/s).

## Checkpoint sizes (ground truth: GGUF header + engine accounting)
- Architecture `qwen35moe`: 41 blocks, 256 experts/layer, top-8, n_ff 512, n_embd 2048,
  vocab 248320, 16 Q heads, 2 KV heads × 256, full-attention every 4th block (≈10-11 KV layers),
  GDN state (ssm) the rest, 1 nextn (MTP) block.
- Expert pool: 41 layers × 3 × [2048,512,256] × 0.6875 B/elem = 22.70 GB = **21.14 GiB** (engine log ✓).
- Routed bytes per row (top-8 of 256, all layers): 21.14 GiB × 8/256 = **0.660 GiB/row** (0.709 GB).
- Dense per verify pass (GPU): ≈1.03 GB — GDN block ≈ 27.4 MB (qkv 11.5 + gate 5.8 + ssm_out ~5.8
  + router 2.1 + shared expert 2.2), full-attn block ≈ 22.3 MB (q 11.5 + o 5.8 + k/v 1.4 + router 2.1
  + shexp 2.2), output head 349.5 MB (read once per batched pass), embd 349.5 MB (startup only).
- KV int4: 10-11 KV layers × 1024 elems/token × 0.5 B = **5632 B/token**
  (→ 0.185 GB at 32k, 0.738 GB at 128k per verify step; 1.476 GB per full 262k slot).
- MTP drafts per step (k=2): 2 × (eh_proj 5.8 MB + output head 349.5 MB) ≈ 0.71 GB VRAM reads.

## Measured behavior (262k int4 baseline, CT 8, MTP 2, greedy sampler engaged)
- Acceptance: 308 of 410 drafts accepted → a = 2.51 tokens per verify step (512 tokens, 204 steps).
- Medians: empty 21.9 tok/s → **114.6 ms/verify step**; 32k 19.5 → 128.6 ms; 128k 11.8 → 212.7 ms.
- Expert slots at 262k: **0/layer** (free 1.28 GiB − MMQ staging 1.03 − reserve 0.77 < 0).
- Engine log pool line (128k prefill): 2,006,288 batch entries all on the CPU pool, 153.7 s.

## Where the time goes (derived from the above; to be confirmed by §9 profiling)
- Pool reads per verify step: U(3 rows) × 0.660 GiB ≈ 0.630 GiB (union ≈ 22.9 of 24 experts).
- empty: 114.6 ms/step − GPU (~4.6 ms dense+heads) − overheads (~8 ms) ≈ **102 ms pool → 6.2 GB/s effective**.
- 128k: same pool ~102 ms + int4 attention reading 0.738 GB/step slowly (~74-95 ms; byte-granular
  loads) + rest ≈ 213 ms ✓ consistent.
- So: **empty/32k are pool-bound; 128k is pool-bound + int4-attention-bound.**

## Ceilings (practical; pool at BW_p GB/s effective, attention at BW_a GB/s, 6 ms overhead)
t_step = 0.630 GiB/BW_p + 2.08 GB/448 + 5632·ctx/BW_a + 6 ms; tok/s = 2.51/t_step × 1000/1

| BW_p | BW_a | empty | 32k | 128k |
|---|---|---|---|---|
| 6 (today) | ~10 (today) | 21.9 | 19.5 | 11.8 |
| 12 | 100 | 39.8 | 38.0 | 31.9 |
| 25 | 250 | 68 | 67 | 62 |

**2× targets (43.85 / 37.87 / 23.60 tok/s) are feasible** with the pool at ≥12 GB/s effective
(empty needs ~13, 32k ~12, 128k ~9 at BW_a 100 GB/s). The gap is ~2-4× on the pool path and
~10-40× on the attention kernel — kernel/config work, not an impossible wall.

## KV/concurrency note
KV pool per full 262k slot = 1.476 GB (int4). Concurrency-1 benches need 1-2 slots; trimming
`--parallel` (if >1) frees VRAM for expert slots (84.6 MB per expert-slot per... per slot across
41 layers), giving hit-rate headroom (prior session: 50 slots → 53% GPU share at 64k).

## Unmeasured / to verify
- Device-copy VRAM bandwidth, RAM stream bandwidth (measure between bench passes, GPU serialized).
- Exact per-part split (pool vs attention vs overhead) via nsys/ncu (§9.0).
- U(3) union exact value; "batch entries" unit in the engine log.
