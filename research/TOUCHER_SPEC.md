# TOUCHER_SPEC — the idle-residency lever (drafted from T2's confirmed stall)

Status: DRAFT (nothing implemented, nothing measured yet; the step-0 diagnostic runs first).
Owner: the continuing research agent. Opt-in gates proposed; the default path stays
byte-identical (the contribution rule: a new feature is opt-in).

## The finding (what was measured)

After a 900-s idle, the FIRST decode round's pool calls pay a large stall, and the
steady rounds do not:

- Q5_K_S capture (row 5, 2026-11-17 14:42Z): the warmup round had **78% of its pool
  SUM in >10 ms calls (max 454 ms/call)** vs the measured round's 8%.
- Q4_K_S capture (row 8, 2026-11-17 17:33Z): the warmup round had **767 calls >10 ms
  = 45.9% of its SUM (max 208 ms; the aggregate 6.99 GB/s)** vs the measured round's
  0.1% (the aggregate 20.07 GB/s).
- The stall transfers across both arenas — the Q5's 21.14 GiB AND the Q4_K_S's
  17.45 GiB — and both arenas run **pageable host memory**: `cudaHostAlloc` FAILED
  for both (the live engine log), so the box's pin cap is below 17.45 GiB.
- The box's dmesg shows recurring `MemoryReclaim`/`drop_caches` events and `dxgk`
  Ioctl-failure lines (WSL GPU driver), consistent with periodic reclaim.

The stall lives in the pool's weight streaming (the host arena's reads), only on the
round after idle → the arena's pages leave their warmed state while nothing runs.

## What this lever is worth (the honest bound)

The excess is the first round only: roughly 1–3 s of pool time per idle→resume
(45.9–78% of one round's pool SUM), then the steady state is identical. **It does not
move the settled 2.00x benchmark cells** (the bench protocol settles + warms up); it
moves the interactive idle→first-token latency and the first prefill after idle.

## Step 0 — the mechanism diagnostic (cheap; run before any code)

Two `/proc` snapshots, before and after the next natural idle ≥900 s (no bench pending,
no server restart):

```sh
PID=$(pgrep -f out/strata | head -1)
grep -E 'VmRSS|VmSwap' /proc/$PID/status
cat /proc/swaps                       # zswap/swap enabled at all?
grep -E 'swap|Swapped' /proc/$PID/smaps | head -20   # per-mapping swap counters
dmesg | grep -iE 'MemoryReclaim|drop_caches' | tail -5
```

Decision rule (pre-registered):
- **VmSwap grows** by arena-scale GBs after idle → the mechanism is swap/zswap of the
  anonymous arena → the toucher (C2) is the primary candidate, mlock (C3) the fallback.
- **VmSwap stays 0** and the stall still reproduces → the mechanism is NOT reclaim →
  record the hypothesis honestly weakened; stop before implementing (do not code a
  lever against an unknown mechanism).

## The candidates

| # | lever | mechanism | cost | risk |
| --- | --- | --- | --- | --- |
| C1 | boundary pre-pay (`STRATA_ARENA_WILLNEED=1`) | one `madvise(MADV_WILLNEED)` over the arena when the engine resumes (Linux; `PrefetchVirtualMemory` on Windows — the codebase already pairs the two, expert_source.hpp:962) | zero steady cost; the page-in moves ahead of the first token | none known |
| C2 | idle toucher (`STRATA_ARENA_TOUCH=1`) | a low-priority thread reads 1 byte per 2 MiB stride every 10 s while idle (~8.9k touches, ~18 KiB/pass); keeps the pages on the active list so reclaim scans skip them | ~0.2 ms CPU/pass; a thread | none known; useless if drop_caches on file-backed pages is the mechanism (the arena is anonymous malloc, so drop_caches should not touch it — the diagnostic decides) |
| C3 | mlock the arena | locks the pages against swap entirely | freezes ~17.45 GiB of a 26 GB box; needs the memlock rlimit | OOM risk for everything else; the same headroom that failed the pin; last resort only |
| C4 | make the pin succeed | raises the pin cap (ulimit/registry) so `cudaHostAlloc` pins and DMA beats the stall class | out of scope here (S11-1 owns the pin question) | — |

Recommended first implementation: **C1 + C2 together, both opt-in, both Linux-only
no-ops on Windows** unless the diagnostic says otherwise. C1 alone already converts
767 scattered per-call faults into one batched populate before the first token.

## Acceptance criteria (pre-registered)

1. After a 900-s idle, the first decode round's pool calls >10 ms share of the pool
   SUM ≤ ~1% (today: 45.9% on the Q4_K_S, 78% on the Q5).
2. The settled cells within ±2% of the anchors (empty 23.51 / ctx32k 23.03 /
   ctx128k 18.19) — the lever must not cost the steady state.
3. The first-response wall time after idle strictly improves (the pre-pay's added
   latency ≤ the stall it removes).
4. `STRATA_ARENA_TOUCH`/`STRATA_ARENA_WILLNEED` unset → the binary's behavior and
   results byte-identical to today's (verified by the same settled-cell A/B).

## Implementation notes (for whoever codes it)

- The arena lives in `include/strata/core/expert_source.hpp` (`arena_`, its byte
  count, set at `open()`; the PLE/arena admission policy lives in
  `include/strata/core/ple_residency.hpp` — do not duplicate it; this lever is
  anti-reclaim, not admission).
- The toucher thread: spawn at `open()` when the gate is set; pause while the decode
  loop marks busy (one atomic); 2 MiB stride, one byte read each, no writes.
- The boundary hook: the engine's idle→first-request path; one madvise per resume,
  debounced by an atomic (no re-arm while in flight).
- Never lock more than the arena's current bytes; never touch the staging buffer
  (its residency is the pool's own concern).

## What this spec deliberately does NOT claim

Nothing here is measured beyond T2's warmup-round distribution. The step-0 diagnostic
is the gate: no implementation before its answer, and the mechanism hypothesis is
recorded as unconfirmed static reasoning until then.
