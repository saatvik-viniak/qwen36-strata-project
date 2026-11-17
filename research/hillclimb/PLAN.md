# PLAN.md — hill-climb log (skill: inference-optimisation)

Mission: 2.00× decode tok/s on empty/ctx32k/ctx128k (512-token greedy, server ctx 262144) per
`auto-research.md` §4/§9. Baseline config is frozen: MAX_CONTEXT=262144, PREFILL=1024, MTP=2,
CPU_THREADS=8, KV=int4, SAMPLING presence_penalty 0, PORT 30000. Guard: peak VRAM < 7.9 GiB.

## Baseline (262k int4, measured — COMPLETE)
| cell | pass-1 | pass-2 | pass-3 | median | 2× target |
|---|---|---|---|---|---|
| empty | 21.92 | 21.86 | — | 21.89 | 43.78 |
| ctx32k | 18.94 | 20.44 | 19.52 | 19.52 | 37.87 |
| ctx128k | 11.80 | 11.66 | — (spread 1.19% ≤ 2%) | 11.73 | 23.46 |

Peaks 7.35-7.38 GiB (guard OK). Targets anchored to the pass-1 table (43.85/37.87/23.60);
medians 21.89/19.52/11.73 are the promotion reference.

## Experiment log (one change per experiment; A/B with controls)
| # | lever | config | result | verdict |
|---|---|---|---|---|
| 0 | baseline | frozen §4 env | 21.89 / 19.52 / 11.73 (medians) | reference |
| A | NO_MMQ → 7 slots + native prompt kernels | STRATA_Q36_NO_MMQ=1 | 23.00 / 18.64 / skipped (30-min rule) | reject: ctx32k −4.5%, prefill 3.4× slower |
| B | CT 5 (workers=cores) | CPU_THREADS=5 | 21.69 / 19.33 / 11.71 | reject: a wash on every cell (−0.9% / −1.0% / −0.2%) |
| C | MTP 3 (draft depth) | MTP=3 | running (trial_runner3) | — |
| D | MMQ + 2 expert slots (B1 at the VRAM edge) | --expert-slots 2 | queued | need-check margin ~13 MB; may refuse |
| 4 | arena hugepages/WILLNEED + pool prefetch | code | pending | — |
| 5 | int4 attention 128-bit loads | code (dd9fee1: uint4 QK read, 16x fewer L1 tx) | candidate built into main, pending WSL build + VERIFY + bench | attention is transaction-bound (45-57x above the DRAM floor) — the 128k cell's main lever |
| 6 | MMQ staging sub-chunk shrink → slots+MMQ compose | code | pending | staging 2×max_layer→~4× smaller keeps 7 slots beside the fast prefill |
| 7 | Q5_K multi-token AVX-2 expert kernels | code | pending | type 13 gu+down fall to the AVX1 singleton today; 2.0-2.4× precedent; the empty/32k compute wall |

## Walls (evidence in THEORY.md)
1. CPU expert pool: 0.630 GiB/step at ~6 GB/s effective (empty/32k = 85-90% of step time).
2. int4 attention kernel: 0.738 GB/step at byte-granular loads (128k).
3. CUDA graphs disabled in hybrid mode → per-step launch overhead.

## Queue rules
Serialize GPU jobs (one bench/one server at a time); detach with setsid (proven survival);
no CPU-bandwidth-heavy tests while decode benches run; watchdog on 7.9 GiB for VRAM-risky trials.
