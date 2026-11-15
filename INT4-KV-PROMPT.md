# Goal: an int4 KV cache for Strata's Qwen3.6 engine path

## Role and objective
You are working on Strata, a C++/CUDA inference engine. Your goal is to add a **quantised KV cache** to the
Qwen3.6-35B-A3B engine path so that long context becomes possible on an 8 GB graphics card, with text parity
against today's fp32 cache. Work in stages: **f16 → int8 → int4**, each stage building, loading and passing
parity before you start the next. Do not attempt any other performance work.

## Repository and environment
- Repo: `qwen36-strata-project` (a Strata checkout with a few wrappers). Engine path: `src/qwen35/`.
- Main file: `src/qwen35/q36_engine.cu` (~4000 lines). Headers: `src/qwen35/q36_kernels.cuh`.
- Build: `./build_kit.sh` (cmake + ninja, CUDA for sm_86). Incremental rebuilds are fast.
- Engine binary: `out/strata` (or `build/strata` after `build_kit.sh`).
- Serve wrapper: `serve.sh` (writes a JSON config and starts `serve.server --engine strata`).
- Model: `/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf`
  (GGUF architecture `qwen35moe`, block_count 41, nextn_predict_layers 1, so 40 trunk layers + 1 MTP block).
- Hardware: RTX 3070 8 GB, 26 GB RAM. The model peaks at **7.26 GiB VRAM at 32K context today**; the campaign
  guard is **7.9 GiB**.
- Gates: `tools/qwen35/q36_solo_gate.py`, `q36_cmp_gate.py`; engine switch `STRATA_Q36_VERIFY=1` compares the
  old kernel and the new one bit for bit on live activations.

## Why this matters (the numbers you must move)
`alloc_session()` allocates fp32 K and V for **11 attention-bearing layers** (10 full-attention trunk layers plus
the MTP block), each with 2 KV heads and head_dim 256:

```
11 layers x 2 (K,V) x 2 kv heads x 256 head_dim x 4 bytes = 45,056 B per context token
```
| context | fp32 | int8 | int4 |
| ---: | ---: | ---: | ---: |
| 32,768 | 1.41 GiB | 0.70 | 0.35 |
| 65,536 | 2.82 GiB | 1.41 | 0.70 |
| 131,072 | 5.64 GiB | 2.82 | 1.41 |
| 262,114 | 11.3 GiB | 5.6 | 2.8 |

At fp32 the card cannot start 64K or 128K. At int4 it can, and the freed VRAM also lets the engine choose a
larger prompt chunk (it picks the chunk from free VRAM: 512/1024/2048), which is the largest prefill win available.

## Hard constraints
1. **fp32 stays the default.** Add `--kv fp32|f16|int8|int4` to `strata::qwen35::run`'s argument parsing. With no
   flag (or `--kv fp32`) the compiled path must be byte-identical in behaviour to today.
2. Do not change the model file, tokenizer, sampling, prompt format, benchmark, or `serve/`.
3. Do not change `tools/qwen35/*` — those are the parity gates.
4. Keep the flag's validation strict: unknown value → usage error, not a fallback.
5. Every stage must answer correctly before you start the next. A layout bug that produces plausible text is the
   main hazard; the gates below exist to catch it.

## The complete code surface (read these before editing)
The cache dtype appears in exactly these places; there is no hidden serialization or saved-cache format.

| # | Symbol / line (approx) | What it does |
|---|---|---|
| 1 | `struct Sess` ~1200 | `std::vector<float*> conv, S, kc, vc;` — one vector entry per layer |
| 2 | `alloc_session` ~1300, ~1312 | `ss.kc.push_back(dalloc((size_t) g.n_head_kv * ctx * g.head_dim));` and the same for `vc`. `dalloc(n)` = `cudaMalloc(n*4)` + zero. A typed helper `dalloc_t<T>(n)` already exists |
| 3 | `k_attn_prep` ~253-300 | Writes K/V for prompt cells: `kc[((size_t) kh * ctx + pos) * HD + i] = v;` and the V write below it. Layout is `[kv_head][ctx][head_dim]`, rows `ctx` apart |
| 4 | `k_attn_part` ~300-330 | Reads K/V for decode. Note `if (rs.kc) { kc = rs.kc[rs.slot[t]]; vc = rs.vc[rs.slot[t]]; }` — the batch path swaps in a slot's cache |
| 5 | `k_kv_f16` ~431 | Converts a window of cells to `__half` for the prompt GEMMs. **Proof that half-precision K/V operands already work in this engine** |
| 6 | `RowSel` ~245 | `float* const* kc; float* const* vc;` — device table of per-session base pointers, one entry per session |
| 7 | slot tables ~1510 | `hk[li * n_sess + s_] = sess[s_].kc[li];` (and `hv`) — host-side pointer tables used for batch decode |
| 8 | row copy ~2696 | `cudaMemcpy2DAsync(b.kc[l], row, a.kc[l], row, (size_t) a.pos * g.head_dim * 4, (size_t) g.n_head_kv, ...)` — copies a slot's first `pos` cells, per head. The `*4` is `sizeof(float)`; `row` is the row pitch |
| 9 | launches ~1972, ~1984, ~2024 | `k_attn_prep<<<...>>>(..., kc[li], vc[li], ...)`, `k_kv_f16<<<...>>>(kc[li], vc[li], ...)`, `k_attn_part<<<...>>>(..., kc[li], vc[li], ...)` |
| 10 | MTP block | The same pattern at layer index `g.n_layers`; it must use the same layout |

## Design

### Stage 1 — `--kv f16`
- Allocate `__half` caches with `dalloc_t<__half>(n_head_kv * ctx * head_dim)`.
- Kernels take `__half*`, write with `__float2half_rn`, read with `__half2float`.
- Row copies become `pos * head_dim * 2` bytes; pitch stays element-based where the kernels index it.
- `k_kv_f16` can then copy halves directly (or be skipped for the prompt path) — but keep its numerics the same.
- Pass if: text on the parity prompts equals the fp32 build, `STRATA_Q36_VERIFY=1` reports 0 mismatches, and
  `--max-context 65536` starts and answers.

### Stage 2 — `--kv int8`
- Layout: `int8` values `[kv_head][ctx][head_dim]`, plus one `__half` scale per `(kv_head, cell)`.
- Scale: `s = absmax(row) / 127`, quantise `q = round(v / s)`, dequantise `v ~ q * s`. Guard `absmax == 0`.
- Dequantise inside the reader (decode and prompt), not into a full-size float copy.

### Stage 3 — `--kv int4`
- Pack two signed 4-bit values per byte along `head_dim`: 256 values → 128 bytes per row.
- Values in `[-8, 7]`, one `__half` scale per `(kv_head, cell)` = `absmax / 7`, round half to even.
- Packing order is yours, but **document it** and keep the store and load halves of the kernel consistent
  (low nibble = even index is the simplest choice).
- Same layout for the MTP block.
- Expected: 11,264 elements/token x 0.5 B = **5.6 KB/token** → 64K = 0.35 GiB, 262,114 = 1.41 GiB.

## Edge cases that will bite
1. **Slot row copy (site 8).** With packed rows you cannot copy `pos * head_dim * 4` bytes; copy the packed payload
   per head **and** the matching scales. A batch slot's copied start must carry scales, or the first tokens after a
   copy decode from garbage.
2. **Batch pointer tables (sites 6, 7).** `RowSel::kc/vc` and `hk/hv` are `float*`; they must carry the new pointer
   type (or a small `struct KVView { void* data; void* scale; }`).
3. **Last partial group.** Only allocate/read scales for cells that exist; never read past `pos`.
4. **Prompt vs decode paths.** `k_attn_prep` writes, `k_kv_f16`/prompt GEMMs read halves, `k_attn_part` reads for
   decode. All three must agree on layout.
5. **MTP block.** Easy to forget; it is a full attention layer at index `n_layers`.
6. **Zeroed cache.** `dalloc` zeroes memory; with int4 that is a valid (all-zero) code. Do not rely on it for
   correctness at cells that were never written — but do not crash either.
7. **Alignment.** Packed rows are 128 B; keep the base allocation 16-byte aligned (cudaMalloc already is).

## What to run, in this order
```sh
./build_kit.sh                                                     # must succeed, JOBS=1

GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf
./out/strata --native "$GGUF" --max-context 32768 --kv f16  --bench-pp 8 --bench-tg 1
./out/strata --native "$GGUF" --max-context 65536 --kv f16  --bench-pp 8 --bench-tg 1
./out/strata --native "$GGUF" --max-context 65536 --kv int8 --bench-pp 8 --bench-tg 1
./out/strata --native "$GGUF" --max-context 65536 --kv int4 --bench-pp 8 --bench-tg 1
./out/strata --native "$GGUF" --max-context 131072 --kv int4 --bench-pp 8 --bench-tg 1
./out/strata --native "$GGUF" --max-context 262144 --kv int4 --bench-pp 8 --bench-tg 1

STRATA_Q36_VERIFY=1 ./out/strata --native "$GGUF" --max-context 32768 --kv int4 --no-graph \
  --tokens 1,2,3,4,5,6,7,8 --n 16           # old kernel beside new, bit for bit, on live activations

/opt/strata/venv/bin/python tools/qwen35/q36_solo_gate.py      # text parity against the fp32 build
/opt/strata/venv/bin/python tools/qwen35/q36_cmp_gate.py
```

Watch VRAM the whole time: `nvidia-smi --query-gpu=memory.used,memory.total --format=csv -l 2`.
A context that does not fit must fail loudly, never run with a truncated cache.

## Acceptance criteria (all required)
1. `--kv f16`, `--kv int8`, `--kv int4` each build, load and answer.
2. fp32 remains the default and is unchanged (same text, same memory as before the patch).
3. `STRATA_Q36_VERIFY=1` reports **0 mismatches** for the exact paths; if f16/int rounding legitimately differs,
   report the counts per kernel and the magnitude, do not claim zero.
4. `q36_solo_gate.py` and `q36_cmp_gate.py` pass against the fp32 baseline.
5. `--kv int4 --max-context 65536` starts and answers with **peak VRAM < 7.9 GiB**; then 131072; then 262144 if
   the card allows (state the measured peak for each).
6. Greedy text on the parity prompts matches the fp32 baseline; report the match ratio.
7. Decode throughput on the 32K workload is **not worse than 2% below** the fp32 build (a KV change must not cost
   speed; it should gain, because more experts and a bigger chunk fit).

## Deliverable
A patch to `src/qwen35/` (and `include/strata/` if a header changes), plus a note with:
- the flag and its semantics, and the exact byte layout you chose (including nibble order);
- a table: context × dtype → bytes/token, allocated GiB, measured peak GiB, whether it started;
- parity results: gate output, verify counts, greedy match ratio;
- decode/prefill before and after at 32K (same build settings), and the chunk the engine chose;
- what you did **not** test.

## If something does not work
- Wrong text but no crash → layout, nibble order, or a missing scale; test one head and one cell in isolation
  before touching the kernels again.
- Garbage only after a batch slot copy → the scale array is not copied with the rows (edge case 1).
- Correct at 32K, wrong past 64K → an index computed as `int` rather than `size_t`, or a packed row offset that
  assumes fp32 width.
- OOM at 64K with int4 → you probably still allocate an fp32 workspace; find it and size it from the dtype.
Report the failure, the change you tried, and the measurement — do not weaken the guards or the acceptance criteria.
