# Lab notebook — qwen36-strata hill climb (262k int4 KV mission)

Append after every run. Do not delete a failure; it is the map.
Format: | Date | Commit | Change | empty | 32k | 128k | Peak | Verdict | Lesson |

The cells are decode tok/s of a 512-token greedy generation at server context 262144
(prompt 1 / 32768 / 131072). Blank means not measured at this cell.

## Carried forward from the prior sessions (source: docs/KVNOTE.md, docs/Q4KNOTE.md)

Those sessions landed the int4 KV cache (VERIFY 0/6103 mismatches on every dtype, gates,
dump comparisons, 262114 starts at 6.928 GiB) and the Q4_K down-projection patch. Their
serving numbers were measured at 32k server context with a 15.5k-prompt cell — close but
NOT the 262k protocol cells, so they are context rows, not the baseline:

| Date | Commit | Change | empty | 32k | 128k | Peak | Verdict | Lesson |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| 2026-11-15 | a64a20b | int4 KV cache landed + verified (f16/int8/int4; all paths incl. MTP + batch tables; att_rows shrink fixed the 262k refusal: pacc was 2 GiB, now 256 MiB) | - | - | - | 6.93 @262k start | landed | the attention-partials buffer sized from min(chunk,64) rows refused 262k; uniform kGemmT rows fix |
| 2026-11-15 | a64a20b | int8/int4 at 32k land on the model's borderline `\n#` loop on the toy 8-token chart prompt | - | - | - | - | resolved | quantisation noise tips borderline seams on a toy prompt; the cache content itself is within envelope (int8 0.39%, int4 ~7% rel) |
| 2026-11-15 | a64a20b | k_kv_f16 used the K row's scale for V (int8/int4 branches) | - | - | - | - | fixed | the prompt staging reader must use each array's own scale |
| 2026-11-15 | a64a20b | serving at 32k ctx: fp32 21.4 / int4 28.8 empty; int4 wins via expert slots (18 vs 7) | 21.4 | - | - | 7.00 | reference | freed VRAM buys expert slots; decode tracks the slot count |
| 2026-11-15 | a64a20b | SAMPLING={"presence_penalty":0} restores the greedy sampler → MTP drafting engages (was 0 of 0 accepted under the model card's presence_penalty 1.5 default) | 34.0 | - | - | 6.92 | reference | the served sampler decides whether speculative steps run; acceptance 70-78% |
| 2026-11-15 | a64a20b | MTP 4 at 32k ctx | 32.0 | - | - | 6.93 | rejected | marginal drafts accept less (56-63%) and per-step cost grows; MTP 2 stays |
| 2026-11-15 | a64a20b | CPU_THREADS=12 hurt: fp32 21.4→12.3, int4 28.8→16.0 | - | - | - | - | rejected | 13 threads on 6C/12T oversubscribe; leave CT 0 or use 8 (MMQ off) |
| 2026-11-15 | 29299a4's content | long-context answers (needle) int4: 32k ✓ 64k ✓ 128k ✓ "Biscuit" | - | - | 13.4 tok/s (130,813-token prompt, 864 s prefill at 151.4) | 6.96 | parity ok | attention reads the whole quantised cache per step at long ctx |

## This session

| Date | Commit | Change | empty | 32k | 128k | Peak | Verdict | Lesson |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| 2026-11-16 | b81319b | serve.sh KV default restored to fp32 (mission §4: `--kv "${KV:-fp32}"`); int4 work landed to main as 29299a4; notes + PROGRESS.md landed as 9f4dac7 | - | - | - | - | landed | the lane's wrapper had int4 as its default; the engine's own default was already fp32 |
| 2026-11-16 | b81319b | serve_262k.sh first start failed: SAMPLING JSON's inner double quotes were stripped by bash word processing | - | - | - | - | fixed | single-quote the JSON: SAMPLING='{"presence_penalty":0}'; server restarted |
| 2026-11-17 | b81319b | **262k baseline pass 1** (protocol §4: 262144/PREFILL 1024/MTP 2/CT 8/KV int4/greedy sampler): empty 21.92, ctx32k 18.94, ctx128k 11.80 decode tok/s; peaks 7.35-7.38 GiB; drafting engaged all cells (68-75% acceptance); 0 expert slots (placement: free 1.28 GiB - MMQ staging 1.03 - reserve 0.77 < 0) | 21.92 | 18.94 | 11.80 | 7.38 | **baseline recorded** | the wall at every cell is the routed-expert CPU pool (21.14 GiB pageable host RAM, 8 threads warned oversubscribed on 6 cores) + the int4 attention read at long ctx; hybrid mode runs with CUDA graphs OFF |
| 2026-11-17 | b81319b | baseline repeats (passes 2-3, median of 3 measured rounds) — running | - | - | - | - | pending | the protocol's variance rule (>2% between repeats → 3 rounds, median + spread) |
| 2026-11-17 | b81319b | pass-2 background job **killed at checkpoint** mid-ctx128k: empty (21.86) + ctx32k (warmup-int 19.6 / measured-int 20.4) had completed; the numbers live only in the engine log; ctx128k never ran | - | - | - | - | lost, recovered from log | a harness checkpoint kills its background jobs at turn end; anything long-running must be `setsid nohup`-detached INSIDE WSL (and the launcher must keep the client alive ~4 s past spawn — proven) |
| 2026-11-17 | b81319b | bench.py anatomy learned: each invocation internally runs 2 requests (warmup-int + measured-int) and reports the measured one → an external warmup doubles the ctx128k prefill cost (~60 min per cell at 3 invocations) | - | - | - | - | workaround | for 128k rounds rely on bench.py's internal warmup; skip the external warmup |
| 2026-11-17 | b81319b | pass-3 ctx32k measured: **19.52** (internal warmup 19.6, peak 7.38 GiB) → ctx32k median = 19.52 of {18.94, 20.4, 19.52} | - | 19.52 | - | 7.38 | repeat done | ctx32k spread 18.94-20.4 (7.7%) confirms the 2% variance rule; medians required |
| 2026-11-17 | b81319b | GGUF header fully parsed (custom KV dialect: STRING=8/ARRAY=9): 41 blocks, 256 experts top-8, n_ff 512, vocab 248320, 16Q/2KV heads × 256, full-attn every 4th block, GDN the rest, nextn MTP block; expert pool 41×3×268.4M×0.6875 B = 22.70 GB = the engine's 21.14 GiB ✓; KV int4 = 5632 B/token → 0.738 GB per verify step at 128k | - | - | - | - | ceilings grounded | all ceiling inputs now come from the checkpoint, not guesses (`research/hillclimb/THEORY.md`) |
| 2026-11-17 | b81319b | ceiling verdict: empty/32k are pool-bound (pool ~6 GB/s effective of a ~35-40 GB/s DDR4 stream), 128k is pool + slow int4 attention; 2x targets feasible at pool ≥12 GB/s + attention ≥100 GB/s | - | - | - | - | targets reachable | the levers in order: CT 5, NO_MMQ slots, hugepages/WILLNEED + pool prefetch (code), int4 attention 128-bit loads (code), parallel/KV-pool trim |
| 2026-11-17 | b81319b | ctx128k pass-2/pass-3 re-running via detached bench_runner.sh (server survived the probe exit; port 30000 healthy at 01:41Z) | - | - | (pending) | - | pending | skip pass-3 if pass-2 lands within 2% of 11.80 |
