# Research instructions

**Project:** Strata's Qwen3.6-35B-A3B engine (`qwen36-strata-project`), on `windows-rig`
(RTX 3070 8 GB, 26 GB RAM, WSL2 Ubuntu, CUDA 12.6, sm_86).
**Mission:** a compatible 4-bit KV cache, then a measured **2× decode** at the model's full
262,114-token context.
**How to use this file:** read it before every run. Append to the lab notebook in §8 after every
run, including failures. Do not rewrite the goal or the guards to make a run look better.

---

## 1. The goal, in order

1. **Land a Q4 KV cache that is compatible with the engine and the model.** Opt-in flag, fp32
   default, packed 4-bit K and V, per-group scales, all attention paths and the MTP block. It must
   start and answer at `--max-context 262144` under 7.9 GiB of VRAM.
2. **Record the baseline at 262k context.** Empty context (1-token prompt), 32k and 128k prompts.
   Decode is a **512-token** generation, concurrency 1, greedy. Record decode tok/s, prefill tok/s,
   TTFT, peak VRAM and text parity. This is the "initial tps" the target refers to.
3. **Climb until decode is at least 2× the initial tps on every measured cell.** Not 1.9×. A win on
   one cell is a milestone, not the end.
4. **Hand back a reproducible tree, the numbers, the failures and the wall.** If 2× is not reached,
   say exactly what stopped it, with measurements.

Work in that order. Do not tune speed before the Q4 cache exists and the 262k baseline is recorded;
a speed number from fp32 KV at 32k is not the baseline this run is judged against.

---

## 2. The machine, model and engine

- **Rig:** `windows-rig`, one RTX 3070 (8 GB, 448 GB/s, sm_86), Ryzen 5 3600X (6 cores / 12
  threads), 26 GB RAM, WSL2 Ubuntu. The GPU is shared by the judge and the lanes; never start a
  second model while a measurement is running.
- **Model:** `llmfan46/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf`
  (24.6 GB), architecture `qwen35moe`, 41 blocks (40 trunk + 1 MTP), `n_embd` 2048, `n_ff` 512,
  2 KV heads, `head_dim` 256, context 262,114. The MTP block is a full attention layer at index
  `n_layers` (40) and uses the same KV cache layout as the trunk.
- **Engine:** Strata, built from this tree. The Qwen3.6 path is `src/qwen35/`:
  `q36_engine.cu` (engine, KV allocation, attention kernels, MTP, chunk selection),
  `q36_kernels.cuh`, `q36_main.cpp`. The server is `serve/`; the wrapper is `serve.sh`;
  `build_kit.sh` compiles and stages `build/`.
- **Benchmark kit:** `qwen36-strata-kit`, `run/bench.py` over `/v1/chat/completions`. Strata has no
  `/v1/completions`; count output tokens by tokenizing the response, never by counting SSE chunks.
- **Current baseline:** fp32 KV, prompt chunk 1024, 32k server context: **21.6 tok/s decode at
  ctx0**, **7.26 GiB peak**. That is the last published number, not this run's baseline.
- **The KV arithmetic (trust the code, then measure):** 11 attention-bearing layers × 2 (K,V) ×
  2 KV heads × 256 dims = **11,264 values per context token**.

  | Context | fp32 (4 B/value) | int8 (1 B) | int4 packed (0.5 B) |
  | ---: | ---: | ---: | ---: |
  | 32,768 | 1.375 GiB | 0.344 GiB | 0.172 GiB |
  | 65,536 | 2.75 GiB | 0.688 GiB | 0.344 GiB |
  | 131,072 | 5.5 GiB | 1.375 GiB | 0.688 GiB |
  | 262,114 | 11.0 GiB | 2.75 GiB | **1.375 GiB** |

  int4 is 8× smaller than fp32, not 4×. Some notes in this repo halve that ratio; the formula and
  the measured `nvidia-smi` peak are the truth. Verify the bytes/token from the allocation before
  trusting any table, and record the measured number.

**The fit consequence:** the non-KV model footprint was about 5.9 GiB when the 32k fp32 peak was
7.26 GiB. At 262k the int4 cache is 1.375 GiB, so the total is about 7.26 GiB — inside 7.9, but
with only ~0.6 GiB of headroom for expert slots and scratch. **Do not assume the 4K slot count
(50–55) still fits at 262k.** Re-tune expert placement at 262k. int8 at 262k is 2.75 GiB and does
not fit with the model; int4 is the only path to 262k on this card.

---

## 3. What "compatible Q4 KV" means

A Q4 cache is compatible when all of the following are true.

1. **Opt-in.** `--kv fp32|f16|int8|int4` in `strata::qwen35::run`; with no flag (or `fp32`) the
   compiled path behaves exactly as today. An unknown value is a usage error, never a fallback.
2. **Packed.** Two signed 4-bit values per byte along `head_dim`: 256 values = 128 bytes per row.
   Values in `[-8, 7]`, round half to even. Document the nibble order (low nibble = even index is
   the simplest) and keep store and load consistent.
3. **Scaled.** One scale per `(layer, K/V, kv_head, group of 32 or 64 cells)`. `s = absmax / 7`
   for int4, `absmax / 127` for int8; guard `absmax == 0`. Store scales as `__half` unless a
   measurement says fp8 is better.
4. **Threaded through every path.** `alloc_session` (all 10 trunk layers + the MTP block),
   `k_attn_prep` (prompt write), `k_attn_part` (decode and verify, including the `rs.kc` / `rs.vc`
   batch-slot swap), `k_kv_f16` (the prompt staging point), `RowSel::kc/vc`, the slot tables
   `hk`/`hv`, the slot row copies (`cudaMemcpy2DAsync` sites), and the MTP block. There is no
   serialized cache format to migrate.
5. **Correct at the boundaries.** The last partial group, positions past the prompt, and a batch
   slot's copied start must carry the packed rows **and** the scales. A batch slot that copies
   only the payload decodes garbage from its first token.
6. **Parity-proven.** `STRATA_Q36_VERIFY=1` compares the old kernel and the new one on live
   activations; report 0 mismatches on the exact paths, or the per-kernel counts and magnitude
   where f16/int rounding legitimately differs. `tools/qwen35/q36_solo_gate.py` and
   `q36_cmp_gate.py` must pass. Greedy text on the parity prompts must match the fp32 baseline at
   `match_rate >= 0.95` on every measured cell. A plausible-but-different answer is a layout bug,
   not a result.
7. **262k starts.** `--max-context 262144 --kv int4` must start, serve, and answer under 7.9 GiB
   peak. A context that does not fit must fail loudly; never run with a truncated cache.

`INT4-KV-PROMPT.md` in this repo has the full code surface and the staged f16 → int8 → int4 plan.
If `--kv int4` is already in the tree, verify it against these seven points before measuring. If it
is not, implementing it is the first trial, and its baseline is the first result.

---

## 4. Baseline protocol (do this before any speed work)

Pin the exact commit, flags and model hash in the notebook. Build with the lane's memory limit:

```sh
JOBS=1 ./build_kit.sh
```

Serve at the full context, with the Q4 cache and the current best-known flags:

```sh
export MODEL_GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf
export MAX_CONTEXT=262144
export PREFILL=1024
export MTP=2
export CPU_THREADS=8
export PORT=30000
export KV=int4
./serve.sh
```

The cells are the measured workload:

| Cell | prompt tokens | output tokens | concurrency | sampling |
| --- | ---: | ---: | ---: | --- |
| empty | 1 | **512** | 1 | greedy |
| ctx32k | 32,768 | **512** | 1 | greedy |
| ctx128k | 131,072 | **512** | 1 | greedy |

Protocol:

- One warmup round, then one measured round. If the measured decode varies by more than 2% between
  repeats, run three measured rounds and take the median and the spread.
- **Decode tps = 512 / (time of the 512th output token − time of the 1st output token).** Not 2048
  tokens, not chunks, not a rate printed by the server.
- **Prefill tps = prompt tokens / TTFT**, using the **cold** warmup TTFT. The measured round may be
  prefix-cache-primed; report that number separately, labelled.
- Peak VRAM: sample `nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits` at 2 Hz
  during the measured round; report the peak. It includes the ~818 MiB of WSL/host overhead.
- Text parity: the same greedy 512 tokens as the fp32 reference on a fixed prompt set; report the
  match ratio. Use the engine's gates where the kit can call them.
- A cell that cannot start is a **failure to fix**, not a zero to average. Fix the fit first.

Fill this table with the first valid run and never overwrite it; add new rows for later changes.

| Date | Commit | KV | Flags | Cell | Decode tok/s | Prefill tok/s | TTFT ms | Peak GiB | Match | Notes |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
|  |  | int4 |  | empty |  |  |  |  |  |  |
|  |  | int4 |  | ctx32k |  |  |  |  |  |  |
|  |  | int4 |  | ctx128k |  |  |  |  |  |  |

The three decode numbers are **the initial tps**. Everything after is measured against them.

---

## 5. The climb to 2×

- One hypothesis per trial. A trial changes one thing, or one tightly coupled group (e.g. "int4 KV
  layout + its reader"), and records the exact diff.
- Measure all three cells after every trial. A change that helps empty and hurts 128k is not a win
  for this run.
- Promote a change only when the median decode improves by at least 2% on at least one cell and no
  cell regresses by more than 2%, with the guards intact. Keep a negative control.
- Re-run the baseline on the same day when the hardware state changes (driver, power, background
  load, WSL memory).
- The target is **2.00× the initial decode on each cell**. Report the multiplier per cell, not a
  single average.
- At 262k the KV cache is 1.375 GiB; the model is ~5.9 GiB; the card has 8 GiB. The speed win must
  come from using the remaining ~0.6 GiB well (expert slots, scratch), from kernels, and from
  placement — not from assuming the 4K-era slot count still fits.

---

## 6. Constraints and guards

- **Fixed:** the model file, the tokenizer, the sampling (greedy, temperature 0), the prompt
  format, the output length (512), the concurrency (1), the benchmark client and the timer. No
  cached answers, no skipped tokens, no output trimming, no changing the workload to raise a rate.
- **Guards:** peak VRAM per GPU **< 7.9 GiB**; system RAM **< 24 GiB**; no OOM; no truncated
  cache. Text parity **match_rate ≥ 0.95** on every measured cell. A new feature is opt-in; the
  fp32 default path stays byte-identical.
- **Correctness before speed.** A speed win that produces different-but-plausible text is a loss.
  Test one head and one cell in isolation before touching the kernels again.
- **One GPU.** The judge and the lanes share it. Do not start a model manually while a measurement
  is running; the judge refuses to time a busy card.
- **Do not weaken a guard or the acceptance criteria to make a trial pass.** Record the failure
  instead.

---

## 7. Budgets

Suggested, not sacred; if you change one, record why.

| Budget | Value | Why |
| --- | --- | --- |
| Wall clock | 720 h (30 days) or until 2×, whichever first | enough for several kernel rewrites |
| Per trial | 60 min | one build + one 512-token run per cell |
| Cell timeout | **1800 s** | 262k prefill + 512 decode does not fit in 900 s |
| Run wrapper timeout | 2400 s | one cell, including server start |
| Lanes | 2 | one GPU; two hypotheses at a time |
| Lane workspace | 32 GiB | the CUDA build needs it |
| Dev-run RSS | 12 GiB | one build/one dev run |
| Concurrent models | 1 | the card is 8 GB |
| LLM budget | no hard cap; one hypothesis per call | use the cheapest model that follows code |
| Model load | once per cell, not per measurement | cold loads are expensive |

If a trial exceeds its budget without a measurement, kill it, record the reason, and do not count
it as a result.

---

## 8. Lab notebook: failures and expected results

Append after every run. Do not delete a failure; it is the map.

| Date | Commit | Change | empty | 32k | 128k | Peak | Verdict | Lesson |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |

For a failure, record: the exact command, the exact error, the file/kernel, the change tried, the
measurement (or none), and the next step. For an expected result, say what you expected before the
run and what you got:

- "int4 KV should cut KV bytes 8× and let 262k start under 7.9 GiB; measured peak X; 128k decode Y;
  expected Z; the gap is ...".
- "Fusing the dequant should remove one full-cache pass; measured decode +N% at 128k, +M% at empty;
  the attention share was ...".
- "The judge refused to time: `target not ready for timing: N MiB in use`; the card was busy with
  ...; the run is invalid, not a zero."

Known failures from earlier work (do not rediscover):

1. **`cell ctx0: killed: timeout` after ~900 s.** The model load plus the first measurement did not
   fit the 900 s cell cap. Use 1800 s and check the server log; a 262k allocation is 1.375 GiB of
   int4 KV before any prompt.
2. **`target not ready for timing: 818 MiB in use before timing`.** The WSL host holds ~818 MiB
   with no compute process; the harness's idle gate was 600 MiB. The rig's harness now bind-mounts
   a patched `cuda.js` with `maxIdleMemoryMiB: 2048`; if a fresh rig does not, raise that gate or
   stop the host's GPU users. Never start a model while the judge times.
3. **`blk.5.experts are Q4_K/Q4_K, which the native expert kernels do not take`.** Q4_K is in
   `STRATA_GU_FMTS` but not in `STRATA_D_FMTS` (`src/kernels/cuda/iq_kernels.cu`). The fix is
   `X(12)` in both `STRATA_D_FMTS` branches; `Q4K-DOWN-PROMPT.md` has it. Q3_K is in neither list
   and is out of scope.
4. **Lane workspace 2 GiB → `SIGKILL (killed: disk)` on every build.** Set workspace 32 GiB and
   dev RSS 12 GiB before resetting; `reset_workers` discards the lane and its build fixes.
5. **The build sandbox has python3 and network but no curl, wget or pip.** `build_kit.sh` fetches
   CMake with python3; build with `JOBS=1`.
6. **A 24.6 GB model on 26 GB of RAM.** Page-cache pressure is real. Watch `free -m` and
   `nvidia-smi` together; Q4_K weights (22.9 GB) are an experiment for this reason, not a free win.
7. **At 262k, int8 KV (2.75 GiB) does not fit with the model; int4 (1.375 GiB) does.** Do not
   report a 262k result from an int8 run that paged.

---

## 9. How to double the tps: hypotheses, in priority order

These are starting points, not facts. Each has a hypothesis, a change, and the measurement that
settles it. Mark the outcome in the notebook.

### 9.0 First, find the wall (do this before the second experiment)

Run `nsys profile` (or Nsight Systems) on a 128k decode and a 512-token generation, then
`ncu` the top five kernels. Record: DRAM throughput vs 448 GB/s, PCIe H2D/D2H bytes per token,
L2 hit rate, SM occupancy, and the share of time in (a) attention, (b) expert GEMMs, (c) expert
copies, (d) norm/rope/sampling/launch. A 2× target without this breakdown is guessing. The most
likely walls on this box, in order, are: PCIe/CPU expert movement, DRAM bandwidth for the expert
weights, attention at 128k, and launch/sync overhead at 512 tokens.

### 9.1 KV and attention

**A1. Fuse int4 dequant into the decode attention.** Read 16-byte chunks (32 values), unpack with
`__byte_perm`/`lop3`, convert with `__half2`, dot with `__hfma2`; accumulate in fp32. Do not
materialize a float or half window. *Measure:* decode at 128k, attention kernel time, DRAM bytes.
*Expected:* removes a full-cache read/write and a launch; the larger the context, the more it
matters.

**A2. Split-K attention over 262k.** One CTA per head cannot hide 1.4 GB of KV latency. Split the
cell range into 8–16 blocks (e.g. 16k cells each), compute partial online-softmax values, and
reduce with a second kernel (flash-decoding). Use `cp.async` and a 2–4 KB tile double buffer.
*Measure:* attention time per token at 128k/262k; occupancy. *Expected:* the biggest attention win
at long context.

**A3. Choose the layout for the access, not for the writer.** Today rows are
`[kv_head][cell][head_dim]`, contiguous over dim. For split-K over cells, a
`[kv_head][dim][cell]` layout makes cell reads coalesced; for a per-cell dot, the current layout
is already 512 B contiguous (int4). Implement both behind the flag and measure; document the
winner. The wrong layout costs more than the quantization saves.

**A4. Scale layout and group size.** One f16 scale per 32/64 cells; load the scales once per tile;
use `__half2`. Sweep group 32/64/128 and K/V separately. *Measure:* parity and tps. *Expected:*
group 64 halves the scale traffic with little quality loss; group 32 is the accuracy fallback.

**A5. Split K/V precision.** K int4 + V int8, K int8 + V int4, K int4 + V fp8 E4M3, K int4 + V f16.
V is usually more sensitive; K int4 is often fine. *Measure:* parity and peak. At 262k, V int8
raises the cache to ~2.1 GiB and may break the 7.9 GiB guard; check before committing.

**A6. A hot ring in fp32/f16.** Keep the newest 1–2k cells in a small fp32 ring for the current
token and the MTP drafts; the old cells stay int4. Cost: 1–2k × 5.6 KB ≈ 5–11 MB. *Measure:*
decode at 128k and parity. *Expected:* a small but real win on the hot path and better draft
acceptance.

**A7. Do not stage the prompt twice.** `k_kv_f16` converts a window of cells to halves for the
prompt GEMMs. For int4, dequantize directly into the GEMM's B operand (or a per-chunk scratch) and
skip a round trip. *Measure:* prefill tps and TTFT at 32k/128k.

**A8. Tensor-core attention.** Dequant int4 → f16 in shared memory and use `mma.sync` m16n8k16 for
QK^T and PV with fp32 accumulation. The 3070 has HMMA; a hand-written flash attention can beat the
SIMT path. Start with one head, one layer, then generalize. *Measure:* kernel time and parity.

**A9. Fuse QK-norm and RoPE into `k_attn_prep`.** One pass over 256 dims instead of separate
kernels; saves a read/write per token. Bigger at prefill, small at decode, but cheap to try.

**A10. Persistent attention.** A persistent kernel that loops over heads/layers avoids launches and
keeps the pipeline full. It cannot keep 1.4 GB in L2 (4 MB), so measure, do not assume.

**A11. Sliding window, if the model has it.** Check the GGUF metadata and the layer pattern: if any
of the attention layers is local/sliding-window, keep only the window for those layers and shrink
the cache. Do not assume all 10 are full attention; verify, then implement.

**A12. Attention sinks + a recent window + sampled old cells.** A research wildcard for 262k: keep
the first few cells, the recent 4k, and a sampled set of old cells. Quality risk; measure parity
before speed.

### 9.2 MoE and layer splits

**B1. Expert slots to the VRAM edge, re-tuned at 262k.** Sweep `--expert-slots` 35–60 and
`--expert-vram` at the 262k cell. The 4K-era 50–55 does not necessarily fit at 262k (the KV is
1.375 GiB). Record peak at empty/32k/128k; stop before 7.9. *Expected:* the single largest
decode lever if experts are paging.

**B2. Pin hot experts.** Count router choices over a 512-token decode; pin the top-K experts per
layer in VRAM, LRU the rest. *Measure:* hit rate and tps. *Expected:* if the router has temporal
locality, this cuts PCIe substantially.

**B3. Prefetch the next layer's experts.** The router of layer L is known before its expert GEMM;
issue async H2D for the top experts while attention of L runs, on a second stream with pinned host
memory. *Measure:* PCIe bytes hidden and decode tps. *Expected:* hides 30–60% of the expert copy
time if the copy is the wall.

**B4. Split by layer, not only by expert.** Add `--gpu-layers N` (or the existing equivalent):
keep the first N layers' weights on the GPU and the rest on CPU; pipeline the CPU expert GEMM of
layer L with the GPU attention of layer L. The dependency chain prevents full overlap, but the
independent halves (attention vs routed experts) can overlap. *Measure:* per-layer timeline and
decode tps for N = 0, 8, 12, 16.

**B5. Keep the shared expert resident.** If the model has a shared expert, it is small and always
used; keep it on the GPU and put the routed experts on CPU (or the reverse, if the router is
sparse enough). Check the GGUF tensor names before writing code.

**B6. MMQ / V2K / Q8_PACKED.** The prompt path is 1.7× faster with MMQ in the earlier measurements
(153 vs 89 tok/s prefill). For decode, test `STRATA_EXPERT_V2K` and `STRATA_Q8_PACKED`; keep the
packed weights (`STRATA_Q36_KEEP_PACKED`) to avoid a dequant pass. *Measure:* decode and prefill
separately; the best prompt kernel may not be the best decode kernel.

**B7. Fuse gate/up/down.** Gate and up share the input; one kernel with two outputs, then fuse SiLU
and the multiply into the down input. Saves reads/writes of the intermediate and a launch per
layer.

**B8. Sort tokens by expert.** Concurrency is 1, but MTP drafts 2–4 tokens per step; group them by
expert and run one grouped kernel per expert. Measure the acceptance and the kernel time.

**B9. Q4_K weights.** The Q4_K file is 22.9 GB vs 24.6; less RAM pressure and less PCIe per expert.
It needs `X(12)` in `STRATA_D_FMTS` (`Q4K-DOWN-PROMPT.md`); the earlier local run saw +21% empty,
+3% at 32k, +15% at 4K prefill. A different weights file is a **new baseline**, not an exact-parity
candidate. Test at 262k with int4 KV.

**B10. RAM and disk.** `mmap` the model with `MADV_WILLNEED`/`MADV_HUGEPAGE`, `mlock` the hot
experts, keep the model on the fastest NVMe, and stop page-cache thrash. Watch `free -m` and
`nvidia-smi` together. A paging model is slower than a smaller quant.

**B11. CPU threads and affinity.** 8 threads on 6 physical cores, one per physical core, no SMT
siblings; the earlier run found `CPU_THREADS=8` beat the pool default by 4.9%. Pin the expert GEMM
threads and leave a core for the attention/launch path.

**B12. Two streams.** Attention on stream A, expert H2D/GEMM on stream B; events per layer; overlap
the independent work. Do not overlap dependent work and call it a win.

### 9.3 Decode and launch

**C1. CUDA graphs.** Capture the decode step per shape and update pointers, or bucket by context
ranges. 512 tokens × 40 layers × several launches is a lot of overhead. *Measure:* launch time with
Nsight, decode tps. *Expected:* a few percent at empty, more at 128k if the step has many small
launches.

**C2. Fuse the small ops.** RMSNorm + QKV + RoPE, residual + norm, SiLU + multiply, add + norm.
Each fusion removes a kernel and a pass over 2048 floats.

**C3. Persistent MoE.** A persistent kernel that takes expert work from a device queue can cut the
per-layer launch and improve cache reuse. More invasive; do it after the graph and fusions.

**C4. No allocations in the decode path.** Preallocate all scratch, graph pools included; a
`cudaMalloc` in a 512-token loop is a stall.

**C5. MTP depth.** Sweep `--mtp` 0/1/2/3/4 and `--batch-mtp`. The earlier local run had 2 beat 3
(45.8 vs 42.3 empty); re-test at 262k, where the draft acceptance changes. *Measure:* tokens per
step and acceptance, not just tok/s.

**C6. One sync per token.** Device-side routing, one `cudaStreamSynchronize` per token, not per
layer. Measure the gap between kernels in Nsight.

**C7. Warp-specialized attention.** One warp loads KV, one computes, one stores; `cp.async` and
`__syncwarp`. This is A2's natural implementation.

**C8. Clocks and power.** Check `nvidia-smi --query-gpu=clocks.sm,clocks.mem,power.draw` under
load; a 3070 that downclocks at long context loses percent-level performance. Keep the 220 W limit;
do not overclock until the kernel work is done.

### 9.4 Memory and bandwidth

**D1. Roofline first.** If DRAM throughput is below ~60% of 448 GB/s, fix the access pattern before
adding math. If PCIe is the wall, expert placement is the lever, not the attention kernel.

**D2. 128-bit loads.** int4 rows are 128 B; load 16 B per thread and unpack 32 values. Avoid byte
loads and per-value conversions.

**D3. Alignment and padding.** 128 B rows, 256 B `cudaMalloc` bases, pad rows to 128, avoid bank
conflicts. A misaligned packed row costs more than the compression saves.

**D4. L2 persistence.** 4 MB L2; pin the current layer's scales or hot rows, not the whole cache.
Measure the hit rate.

**D5. Compress more.** 3-bit K, 4-bit V; group 128; fp8 E4M3 storage. At 262k every 0.1 GiB of KV
is an expert slot. Measure parity before speed.

**D6. Never copy the whole cache per token.** The decode reads all cells; the only real cuts are
quantization, split-K and a hot ring. A per-token `cudaMemcpy` of the cache is a bug.

### 9.5 Drafting

**E1. MTP depth sweep** at 262k (2 was best at 4K; re-measure). **E2. Tree drafting:** draft a
small tree, verify in one pass with a tree mask; higher acceptance than a chain. **E3. Draft KV in
lower precision:** the MTP block's cache can be more aggressive; verification corrects it. Measure
acceptance. **E4. A smaller draft model:** only if the engine already supports it; MTP is native.
**E5. Batch MTP:** 2–4 drafts per step; measure tokens/step.

### 9.6 Wildcards (rank after the measured wins)

- **F1. Per-layer KV precision.** Some layers tolerate int4, some need int8; choose by measured
  attention entropy and parity. A mixed cache can buy fit or quality.
- **F2. Sinks + window + sampling.** Keep the first cells, a recent window, and a sampled old set;
  measure parity at 128k.
- **F3. Token eviction by attention score.** Re-evaluate every N tokens; research, quality risk.
- **F4. Expert pruning at runtime.** Skip experts below a router threshold; quality risk; measure.
- **F5. FP8 KV.** Ampere has no FP8 tensor cores, but E4M3 storage dequantized to f16 gives
  int8 size with a better range; test K or V.
- **F6. Asymmetric K/V + group 128 + f16 scales.** The combination that fits 262k with the most
  experts; sweep it as one candidate.
- **F7. WSL/Windows tuning.** Keep the model on the fastest NVMe, exclude it from Defender scans,
  check WSL memory and CPU pinning; measure I/O at load.
- **F8. Overclock/undervolt.** +100 MHz core / +500 memory for 3–5%; only after the kernels; check
  stability over a 512-token run.
- **F9. Two streams for shared vs routed experts.** Overlap independent halves; measure.
- **F10. Re-measure the negative control.** A "win" that disappears on a same-day baseline is noise.

### 9.7 What not to do

- Do not change the model, tokenizer, prompt, output length, concurrency or timer.
- Do not report a rate from a different workload, a prefix-cached round, or a warmup.
- Do not trade text quality for speed without measuring parity on every cell.
- Do not assume the 4K slot count fits at 262k; re-tune.
- Do not count a cell that failed to start as zero; fix it.

---

## 10. Reporting and handoff

A run is done when the tree has:

1. the Q4 KV flag and layout, fp32 default unchanged;
2. the parity evidence (`STRATA_Q36_VERIFY=1`, both gates, greedy match ratio);
3. the baseline table at empty/32k/128k with a 512-token decode;
4. the final table at 2× (or the wall, with evidence);
5. the lab notebook of failures and expected-vs-actual;
6. the exact commit, flags, model hash and commands;
7. the untested list.

The note must say what was **not** tested. A claim without a measurement is a hypothesis, and the
notebook says so.

---

## 11. Appendix: commands and traps

```sh
# build (lane memory limit)
JOBS=1 ./build_kit.sh

# serve the seed at the full context
MODEL_GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf \
MAX_CONTEXT=262144 PREFILL=1024 MTP=2 CPU_THREADS=8 PORT=30000 KV=int4 ./serve.sh

# health and a first answer
curl -s http://127.0.0.1:30000/health
curl -s http://127.0.0.1:30000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.6-35b-a3b","messages":[{"role":"user","content":"hi"}],"max_tokens":8}'

# parity and A/B
STRATA_Q36_VERIFY=1 ./out/strata --native "$MODEL_GGUF" --max-context 262144 --kv int4 --no-graph
STRATA_Q36_OLD_KERNELS=1 ./out/strata --native "$MODEL_GGUF" --max-context 32768 --kv fp32
/opt/strata/venv/bin/python tools/qwen35/q36_solo_gate.py
/opt/strata/venv/bin/python tools/qwen35/q36_cmp_gate.py
```

Traps already paid for: the 900 s cell cap (use 1800), the 600 MiB judge idle gate vs the 818 MiB
WSL host (patched to 2048 on this rig), the 2 GiB lane workspace (use 32), the 4 GiB dev RSS (use
12), the no-curl build sandbox, `reset_workers` wiping a lane, and Q4_K down-projections missing
from `STRATA_D_FMTS` (the `X(12)` patch). The engine log is `strata-qwen36.log`; `MTP block loaded`
and `prompt chunk N` are the lines to check.
