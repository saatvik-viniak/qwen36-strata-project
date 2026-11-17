# PLAN.md — hill-climb log (skill: inference-optimisation)

Mission: 2.00× decode tok/s on empty/ctx32k/ctx128k (512-token greedy, server ctx 262144) per
`auto-research.md` §4/§9. Baseline config is frozen: MAX_CONTEXT=262144, PREFILL=1024, MTP=2,
CPU_THREADS=8, KV=int4, SAMPLING presence_penalty 0, PORT 30000. Guard: peak VRAM < 7.9 GiB.

## Baseline (262k int4, measured)
| cell | pass-1 | pass-2 | pass-3 | median | 2× target |
|---|---|---|---|---|---|
| empty | 21.92 | 21.86 | — | 21.92 | 43.85 |
| ctx32k | 18.94 | 20.4 (log-reconstructed) | 19.52 | 19.52 | 37.87 |
| ctx128k | 11.80 | (died prefill) | (running) | — | 23.60 |

Peaks 7.35-7.38 GiB (guard OK). Pass-2 empty+32k numbers came from the engine log after the
background job was killed mid-run (checkpoint kill; lesson recorded). Pass-2 ctx128k + pass-3
ctx32k/128k re-run now (bench_runner.sh, detached, survives client exit).

## Experiment log (one change per experiment; A/B with controls)
| # | lever | config | result | verdict |
|---|---|---|---|---|
| 0 | baseline | frozen §4 env | 21.9 / 19.5 / 11.8 | reference |
| 1 | NO_MMQ → expert slots ~6-9 | STRATA_Q36_NO_MMQ=1 | pending | — |
| 2 | CT 5 (workers=cores) | CPU_THREADS=5 | pending | — |
| 3 | MTP 3 (draft depth) | MTP=3 | pending | — |
| 4 | arena hugepages/WILLNEED + pool prefetch | code | pending | — |
| 5 | int4 attention 128-bit loads | code | pending | — |

## Walls (evidence in THEORY.md)
1. CPU expert pool: 0.630 GiB/step at ~6 GB/s effective (empty/32k = 85-90% of step time).
2. int4 attention kernel: 0.738 GB/step at byte-granular loads (128k).
3. CUDA graphs disabled in hybrid mode → per-step launch overhead.

## Queue rules
Serialize GPU jobs (one bench/one server at a time); detach with setsid (proven survival);
no CPU-bandwidth-heavy tests while decode benches run; watchdog on 7.9 GiB for VRAM-risky trials.
