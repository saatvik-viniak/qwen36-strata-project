# int4 / int8 / f16 KV cache for the Qwen3.6 engine path

A quantised KV cache (fp32 -> f16 -> int8 -> int4) for the Qwen3.6-35B-A3B engine path
(`src/qwen35/q36_engine.cu`): `--kv` picks the dtype, fp32 (the default) stays the old path bit
for bit, and the quantised dtypes trade a little text agreement at borderline tokens for a 4-8x
smaller cache - 64K/128K/262114 contexts fit under 7.9 GiB on the RTX 3070, and int4 decodes
faster than fp32 at 32K because the freed VRAM buys expert slots.

## Flag and semantics

`--kv fp32|f16|int8|int4` in `strata::qwen35::run` (`src/qwen35/q36_engine.cu`), default `fp32`.
Unknown value -> usage error (exit 2), never a fallback. With no flag the compiled path is
today's fp32 path bit for bit (same kernels, same arithmetic, same allocations).

## Byte layout

All dtypes keep the same cache layout: `[kv_head][ctx][head_dim]`, rows `ctx` cells apart
(2 KV heads, head_dim 256). Per layer there are two arrays (K and V); the MTP block is an
attention layer at index n_layers and uses the same layout.

| dtype | values | scale | bytes/token (11 attn layers + MTP, K+V, 2 heads x 256) |
| --- | --- | --- | --- |
| fp32 | `float`, 4 B/element | none | 45,056 |
| f16 | `__half`, RN on write | none | 22,528 |
| int8 | `int8_t` code, round-nearest-even, [-127, 127] | `__half` per (kv_head, cell) = absmax/127 | 11,264 + 88 |
| int4 | two signed 4-bit per byte, low nibble = the even dim, high nibble = the odd dim, range [-8, 7] | `__half` per (kv_head, cell) = absmax/7 | 5,632 + 88 |

One session's K / V at each context (the 11 attention layers + the MTP block, GiB):

| context | fp32 | f16 | int8 | int4 |
| --- | --- | --- | --- | --- |
| 32,768 | 1.38 | 0.69 | 0.35 | 0.17 |
| 65,536 | 2.75 | 1.37 | 0.69 | 0.35 |
| 131,072 | 5.50 | 2.75 | 1.38 | 0.70 |
| 262,144 | 11.00 | 5.50 | 2.77 | 1.40 |

fp32 at 262144 (11.0 GiB) cannot fit beside the model on an 8 GiB card and is refused loudly by the
one-session fit guard; int4's 1.40 GiB fits with room for the experts and the buffers.

- Scales: `[kv_head][ctx]`, one `__half` per row. absmax == 0 -> scale 0, codes 0 (dequant 0*0 = 0).
- int4 quantisation: `s = absmax(row)/7` (stored as fp16), `q = __float2int_rn(v/s)` (round half to
  even), clamped to [-8, 7]; dequant `v ~ q*s` in the reader (decode `k_attn_part`, prompt staging
  `k_kv_f16`), never a full-size float copy.
- int8 quantisation: same with `s = absmax(row)/127`, code range [-127, 127].

## Code surface touched

- kernels: `k_attn_prep`, `k_attn_part`, `k_kv_f16` are now templates over the cache dtype
  (`KV_F32` instantiation is the old kernel verbatim).
- `KVCell { void* data; __half* scale; }` replaces the raw `float*` in the kernels, in `RowSel`
  (the batch rows' per-session table) and in the device tables `d_kctab` / `d_vctab`.
- `Sess::kc/vc` are `void*` + per-session scale vectors `ksc/vsc`; `alloc_session` allocates per
  dtype (`kv_alloc`).
- `copy_session` copies rows and scales in the row's dtype (pitch `ctx*per_row`, width
  `pos*per_row`; scales pitch `ctx*2`, width `pos*2`).
- The one-session fit guard (`one_session_fit`) and the chunk auto rule take the dtype's
  bytes/token (`kv_bytes_per_token`).
- `att_rows` (the split-K partials' rows) is `n_head * kGemmT` = 256 rows for every dtype, was
  `n_head * min(chunk, 64)`: the split-K branch never runs more than 8 query rows per launch, so the
  partials shrink 8x at long contexts (256 MiB at 262114, was 2 GiB) - that was the 262114 refusals
  conversation memory.

## Measurements

(All numbers from the final binary - the V-scale fix, the uniform `att_rows` and the inert
`STRATA_Q36_KVDUMP` diagnostic - unless a paragraph says otherwise.)

### Stage runs on the final binary (peak VRAM, sampler `.oc/vram_sampl.sh`, logs `.oc/s_*.log`)

| run | rc | peak | notes |
| --- | --- | --- | --- |
| fp32 32768 | 0 | 6.948 GiB | 5 of 256 experts/layer in VRAM |
| f16 65536 | 0 | 6.998 GiB | 6 of 256 slots (0.50 GiB) |
| int8 65536 | 0 | 6.967 GiB | 14 of 256 slots (1.16 GiB) |
| int4 65536 | 0 | 6.928 GiB | 18 of 256 slots (1.49 GiB) |
| int4 131072 | 0 | 6.957 GiB | 12 of 256 slots (0.99 GiB) |
| int4 262114 | 0 | **6.928 GiB** | 0 slots, every expert on the CPU pool - the pre-fix run (`.oc/s_int4_256k.log`) was the loud refusal at 5.265 GiB |

The 262114 refusal (before the fix, kept as `.oc/s_int4_256k.log`) was the attention partials buffer
`pacc` (2048 rows x 1024 chunks x 256 x 4 B = 2 GiB),
allocated for 64 query rows per batch while the split-K branch only ever runs T <= kGemmT = 8 rows per
launch (a prompt chunk of T > 8 takes the GEMM branch above it).  Fix in place, uniform for every dtype:
`att_rows = n_head * kGemmT` (256 rows, 256 MiB at 262114, was 2 GiB).  Each launch writes partial rows
[0, nt * H) with nt <= rows_per, so 256 rows stay in bounds for every T.  The fp32 arithmetic is
unchanged (same kernels, same launches); one side effect shows in the texts: the freed ~224 MiB at 32K
raises the hybrid slot count, and the experts' bits differ between the slot and CPU-pool paths, so the
fp32 texts differ from the old binary's at the natural placement - pinned at 5 slots they match bit for
bit (the gates below).

### The short-prompt "loop" resolved (was bug 3)

The 8-token control prompt (`--tokens 1,2,3,4,5,6,7,8`, control bytes) makes the model continue an
ASCII chart whose line separators (`\n#` = tokens 198, 2) are borderline greedy choices.  A matrix of
runs (dtype x context x graph, 64 tokens, `.oc/mx_*.log`) shows:

- fp32 at 32K eager and f16 at 32K eager produce **bit-identical** text (and so do fp32/f16/int8 at
  4096 with the graph, except fp32 at 4096 itself, see below) - the sane chart text.
- fp32 itself flips the seam tokens between configs: 4096-with-graph at its default 22 hybrid slots
  picks `198 2 9 10 ...`, 32K eager (5 slots) picks `348 10 4838 ...` - and pinning `--expert-slots 5`
  at 4096 reproduces the 32K text exactly.  **The hybrid placement (which experts run in VRAM slots vs
  on the CPU pool) changes the bits**, so any two configs with different slot counts legitimately
  diverge at borderline tokens - a pre-existing engine property, not the KV task's (fp32 is the old
  path verbatim).  fp32 also enters the same `\n#` loop at the tail of its own sane run.
- int8 / int4 at 32K land on the loop from token 0 (`198 2 198 2 ...`): their quantisation noise tips
  the same borderline seams, with the 32K placement's MoE bits on top (18 slots there, 23 at 4096).
  int8 at 4096 (same kernels) does not.
- The cache content is **correct at both contexts**: the dump comparison against fp32 at 32768 gives
  worst relative deviation K 1.65% / V 1.33% (int8) and K 8.3% / V 6.9% (int4) - inside the dtypes'
  envelopes (1/127, ~1/7 per element).  The write path, the row layout and the scales are right.
- Ruled out by isolation: the warmup's leftovers (`--no-warmup` runs identical), the MTP block
  (`--mtp` defaults to 0 here; its layer's cells are zeros in every dtype's dump), and the `att_rows`
  shrink (irrelevant at T=8: one launch of nt <= 8 rows either way; the earlier f16 breakage was the
  shrink patch itself, not a mechanism - reverted and now replaced by the uniform fix above).

So the loop is the model's borderline attractor under quantisation noise on a toy prompt, not a cache
bug; the parity gates on the 10 natural prompts and the long-context answer checks are the text story
that matters.

### Parity gates (10 prompts at 32K, greedy, vs the fp32 baseline dump)

Two tables: the final binary at each dtype's own (natural) placement, and the same comparison with the
hybrid placement pinned to 5 expert slots for every dtype (the old binary's fp32@32K placement), which
removes the placement's effect and isolates the KV dtype.

The placement matters because the routed experts' bits differ between the VRAM-slot path and the CPU
pool path (proven: fp32 at 4096 with the default 22 slots and with `--expert-slots 5` produce
different texts, the latter matching the 32K 5-slot run exactly).  The `pacc` fix above frees ~224 MiB
at 32K, which raises the slot count, so the final binary's fp32 texts legitimately differ from the old
baseline's - pinned at 5 slots they must match bit for bit (checked below).

Natural placement (final binary, each dtype at the slots its cache leaves room for):

| dtype | identical | shape |
| --- | --- | --- |
| fp32 | 4 of 10 | sane texts; the differences vs the old baseline are the placement (see above) |
| f16 | 2 of 10 | sane texts, diverge at tokens 6-47 - fp16 rounding |
| int8 | 3 of 10 | **sane full-length texts** (was 0 of 10 garbage before the k_kv_f16 fix) |
| int4 | 1 of 10 | **sane full-length texts** (was 0 of 10 garbage) |

Pinned placement (5 slots for every dtype; the MoE bits match across dtypes, so the ratio is the KV
dtype alone).  The pinned fp32 run also matches the **old binary's baseline 10 of 10, bit for bit** -
the fp32 default path is bit-identical on the final binary:

| dtype | identical | shape |
| --- | --- | --- |
| fp32 | **10 of 10** | and 10 of 10 vs the old binary's baseline (the bit-identity check) |
| f16 | 3 of 10 | diverges at tokens 2-102, same lengths - fp16 rounding |
| int8 | 4 of 10 | sane full-length texts, diverge at tokens 8-114 |
| int4 | 3 of 10 | sane full-length texts, diverge at tokens 1-50 |

Hunted via a cache dump (`STRATA_Q36_KVDUMP`, a temporary diagnostic).  Findings:

1. **The cache itself is correct.**  The dumps (fp32 vs f16 vs int8 vs int4, the same 8-token prompt,
   cells 0-3 of the first attention layer + the MTP layer) show int8 round-trips within 0.39% relative
   and int4 within ~7% (the expected envelopes; f16 within 0.2%) at 4096, and the same holds at 32768
   (int8 worst K 1.65% / V 1.33%, int4 worst K 8.3% / V 6.9%).  The write path, the row layout and the
   scales are right.
2. **`k_kv_f16` dequantised V with the K row's scale** in its int8 / int4 branches (`vcs` was passed and
   unused) - fixed.  This is the prompt staging reader (long prompts -> the GEMM branch), and explains
   the gates' wrong-first-token-then-semi-coherent outputs.
3. **The "second break" was the model's own borderline attractor**, not a cache bug - see "The
   short-prompt loop resolved" above.  VERIFY's kernel A/B stays 0/6103 mismatches throughout (it does
   not exercise the quantised cache path).

### VERIFY=1 on the final binary (all dtypes)

`STRATA_Q36_VERIFY=1 ./out/strata --native <gguf> --max-context 32768 --kv <dtype> --no-graph
--tokens 1,2,3,4,5,6,7,8 --n 16` reports `6103 comparisons, 0 mismatches` for fp32, f16, int8 and
int4 alike (`.oc/final_all.log`, part 1).  The kernel A/B covers the attention kernels the cache
readers feed; the quantised cache's own round-trip accuracy is the dump comparison above.

### The `STRATA_Q36_KVDUMP` diagnostic stays (documented, not reverted)

The dump patch is two things in `src/qwen35/q36_engine.cu`: the host-side dump helpers after
`copy_session` (comment at line ~2968) and one call site, `if (std::getenv("STRATA_Q36_KVDUMP") !=
nullptr) E.kv_dump(4);` at line 4287, right after the `--tokens` path's `E.process`.  With the env
unset (the default) the branch is never taken and the default path's bytes are unchanged - which the
pinned fp32 gate proves (10 of 10 bit-identical to the old binary's baseline).  Keeping it because:
it is the cache-content evidence tool this task leaned on (the dump comparisons above), it is opt-in
and inert by default, and removing it would force a rebuild plus a full re-gate cycle on a binary
whose behaviour is already proven.  If it is ever unwanted, deleting line 4287 and the helpers after
`copy_session` returns the file to the release shape.

## Deliverable 2: serving at 32K (RTX 3070 8 GB, Ryzen 5 3600X, 26 GB RAM)

The bench is `~/qwen36-strata-kit/run/bench.py` through the serve protocol: chat completions at the
request's `temperature: 0` (greedy), concurrency 1, 2048 output tokens asked.  What the server does
with that request matters twice over: the model stops earlier when it finishes its reply (318-618
tokens in the empty-context cells, 687-1722 in the 15,566-token-prompt cells - the rates below are
per delivered window), and the served sampler decides whether the engine may take speculative
steps (the section on the greedy-sampler config below).  Peaks are nvidia-smi samples.

### Why decode is what it is on this machine

The routed experts (21.14 GiB) sit in pageable host memory; the engine's own pool runs them on 6
CPU threads, and only the hot ones get VRAM slots (the batch-stats lines show 3.8-14.6% of the
batch entries served on the GPU).  That is the ceiling for every dtype; the KV dtype changes how
many expert slots fit beside the cache, and so the hit rate.

Two things the first "tuned" plan got wrong, both fixed by measurement:

1. **`CPU_THREADS=12` hurts.**  13 threads on a 6C/12T Ryzen oversubscribe: fp32 decode fell
   21.4 -> 12.3 tok/s, int4 28.8 -> 16.0 (the int4 MTP 2/3/4 sweep was run at threads 12; the
   int4 threads-0 cells below replace it as the headline numbers).
   Leave `CPU_THREADS` at 0 (the engine's own pool).
2. **MTP drafting never engaged through the serve protocol** (`drafts accepted 0 of 0` in all 27
   requests).  Root cause: the qwen35moe thinking model card serves `presence_penalty 1.5`
   (`serve/server.py` `MODEL_CARD_SAMPLING`), the request's `temperature: 0` wins but the
   penalty sticks, the sampler then `needs_logits()`, and the engine's speculative steps are a
   greedy-sampler-only speed-up.  `serve.sh` now takes `SAMPLING` (the config's `sampling` block,
   e.g. `{"presence_penalty": 0}`) to restore the greedy sampler; `serve/server.py` itself is
   untouched.

### Decode / prefill at 32K, default serve config (MTP 2, threads 0, no SAMPLING)

| cell (prompt / asked out) | fp32 decode | int4 decode | fp32 prefill | int4 prefill | peaks |
| --- | --- | --- | --- | --- | --- |
| empty context (1 tok / 2048) | 21.4 tok/s | **28.8 tok/s** | - | - | 7.00 / 6.92 GiB |
| 15,566-token prompt / 2048 | 16.5 tok/s | **20.0 tok/s** | 159.6 tok/s | 164.9 tok/s | 7.02 / 6.93 GiB |

The int4 cache (5.7 KB/token against fp32's 45 KB) leaves ~1.1 GiB more VRAM for expert slots
(fp32 32K: 7 of 256 slots; int4 32K: 3.58 GiB free at load) and so decodes **faster** than fp32 at
the same config: +35% empty-context, +21% with the 15.5K prompt.  Prefill stays >= 100 tok/s at
both dtypes (147.9-166.5 across every cell run).  The acceptance criterion - int4 decode no more
than 2% below fp32 - passes in the good direction.

(fp32 with `MTP 0` decodes 21.7 tok/s against MTP 2's 21.4 - drafting contributed nothing in either
because it never ran; see above.)

### The greedy-sampler (drafting-enabled) config

`SAMPLING='{"presence_penalty": 0}'` (the config's `sampling` block; `serve.sh` writes it, the
request's own fields still win).  With it the sampler stays greedy, the engine's speculative steps
run, and the drafts verify - the text stays the greedy text.  MTP 2 acceptance ran 70-78% per
request (`362 of 490` ... `1008 of 1430` in the engine log); MTP 4 offered more per step but the
marginal drafts accept less (56-63%) and the per-step cost grows, so it is slower:

| cell (prompt / asked out) | fp32 decode (MTP 2) | int4 decode (MTP 2) | fp32 prefill | int4 prefill | peaks |
| --- | --- | --- | --- | --- | --- |
| empty context (1 tok / 2048) | 26.1 tok/s | **34.0 tok/s** | - | - | 7.00 / 6.92 GiB |
| 15,566-token prompt / 2048 | 16.2 tok/s | **22.4 tok/s** | 153.1 tok/s | 147.9 tok/s | 7.03 / 6.93 GiB |

int4 MTP 4 empty-context: 32.0 tok/s (against MTP 2's 34.0), peak 6.93 GiB - MTP 2 wins.

**The >= 60 tok/s decode target is not reached on this machine.**  The best found config is the
one above: 34.0 tok/s (empty context) and 22.4 tok/s (15.5K prompt), prefill >= 148 tok/s.  The
ceiling is not the KV cache: it is the routed experts - 21.14 GiB in pageable host memory served by
the engine's 6-thread CPU pool, with only 3.8-14.6% of the batch entries hitting VRAM slots (the
`hybrid experts` lines).  The KV task's contribution is real and in int4's favour: at the same
config int4 decodes +30% (empty context) to +38% (15.5K prompt) above fp32, because the freed
VRAM buys expert slots; prefill stays within 4% of fp32 and above 100 tok/s everywhere.

### Long-context answers (needle at the top, filler to the context, question at the end)

Driven through the serve protocol (`tools/qwen35/q36_harness.py` `Eng`, ids on stdin: a 32K+-token
`--tokens` string exceeds the OS's per-argument limit).  Needle: "... a scruffy orange dog named
Biscuit."; question: "what was the keeper's dog's name?".  Prompt sizes: 32,413-32,605 ids at 32K, 65,373 at
64K, 130,813-130,909 at 128K.

| ctx | dtype | gen asked | result |
| --- | --- | --- | --- |
| 32,768 | fp32 (control) | 64 | quotes the needle: "... orange dog named Biscuit." |
| 32,768 | int4 | 64 -> 160 -> 256 | the model runs its thinking template; 64 and 160 tokens were cut mid-thought while quoting the needle's start; at 256 tokens the thinking closes (`</think>`) and the answer is **Biscuit** (stop at 189 tokens) |
| 65,536 | int4 | 64 | quotes the needle: "... orange dog named Biscuit." |
| 131,072 | int4 | 160 | full thinking + answer: "The dog's name is Biscuit ... Final Output Generation: Biscuit" |

The engine's own DONE lines give the long-context serving rates for int4: prefill 162.8 tok/s at
32K (32,509 ids in 199.8 s), 151.4 tok/s at 128K (130,813 ids in 864.0 s); decode 20.6 tok/s at 32K
and 13.4 tok/s at 128K (attention reads the whole quantised cache per step).

### Untested

- **Session park/restore (`copy_session`) with quantised rows and scales.**  The admission path
  (line 3861) needs at least two sessions sharing a prompt prefix; the gates, VERIFY and the bench
  cells all ran solo, so the quantised row+scale copy never executed.  Code-reviewed only.
- **Batch admission (`BGEN`) with quantised dtypes.**  The per-session device tables carry
  {data, scale} and the kernels are templated on them, but no batch run was made against a
  quantised cache (no `strata batch:` line in any log).
- **f16 / int8 end to end through the serve protocol and the bench.**  The bench cells run fp32
  and int4 only; f16/int8 went through the stage runs, the gates and the dump comparisons.
- **f16 / int8 at 131072 and 262114.**  The stage runs cover f16/int8/int4 at 65,536 and int4 at
  131,072/262,114; f16 131072 (2.75 GiB of cache) fits by the size math but was not run.
- **MTP drafting with the quantised cache at long contexts.**  With the greedy-sampler config the
  bench cells exercise drafting at 32K (both dtypes); the 64K/128K stage and answer runs had
  drafting off (`--mtp` unset there).
- **Windows, multi-GPU, vision, other cards.**  One RTX 3070 (sm_86), Linux; the `--kv` kernels'
  CUDA paths are the same on other sm_86+ cards but nothing was measured elsewhere.
- **The `--kv` parse edges** were read at lines 4115-4127 (`fprintf` + `return 2` before any model
  load) and are exercised: `--kv bogus` and `--kv fp16` print
  `strata-q36: --kv takes fp32 | f16 | int8 | int4 (got ...)` and exit 2, a valueless `--kv`
  prints `strata-q36: --kv needs a value` and exits 2 - all three at the arg parse, before any
  model load (`.oc/final_tuned.log`).  Note the binary's top-level usage needs `--native` +
  `--tokens` before qwen35's `run()` (and so the parse) is reached at all.



