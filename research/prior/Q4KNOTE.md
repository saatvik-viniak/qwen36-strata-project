# [Engine] Q4_K expert down-projections load in the Qwen3.6 engine path

Patch: `src/kernels/cuda/iq_kernels.cu`, both `STRATA_D_FMTS` branches (lines ~853-858), entry `X(12)`
(GGML_TYPE_Q4_K) inserted after `X(8)` before `X(13)`, no reordering, plus the comment line
"Q4_K gate/up was already allowed; Qwen3.6 Q4_K_S/M also store the expert down projections as Q4_K."
Build: `JOBS=1 ./build_kit.sh` → RC 0, `out/strata` 85,072,112 B (Nov 15 09:48). Every `Fmt<12>` member
the template kernels need already existed (`qk = 256`, `ipb`, `VDR`, `vec_dot_q4_K_q8_1`, `dq_q4_k`,
`iq_row_bytes` case 12, `STRATA_MMVQ_FMTS X(12)`), so no second list proved necessary.

## Why Q4_K downs were excluded, and what the patch does

`native_expert_supported()` (iq_kernels.cu:5480) requires the gate/up type **and** the down type to be in
their lists: `gu_qk(gu) > 0 && d_qk(down) > 0 && iq_row_bytes(...) > 0 && is_iq(gu) && is_iq(down) && ...`.
`STRATA_GU_FMTS` had `X(12)` (Q4_K gate/up) but `STRATA_D_FMTS` did not, so `d_qk(Q4_K)` read the empty
switch and every uniform-Q4_K file was refused at load:

    strata-q36: blk.5.experts are Q4_K/Q4_K, which the native expert kernels do not take

The excluded case was the plain llama-quantize `_M`/`_S` tier of this repo (`Qwen3.6-35B-A3B-...-GGUF`):
its expert down projections are Q4_K on most layers. The engine already took the dynamic-quant layouts
(Unsloth UD files: gate/up Q4_K with Q5_K/Q6_K/Q8_0 down — `X(13)`, `X(14)`, `X(6)` in `STRATA_D_FMTS`)
and the MMQ prompt path already had Q4_K (`MMQ::supported`, moe_mmq.cu:342, under `STRATA_MMQ_KQUANTS`,
which build_kit.sh sets ON; the strata_kq DSO covers it, cmake/backends/cuda.cmake:221 → `kq_ok()` →
`kq::available()`).

## The tested files

`llmfan46/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-GGUF`, 753 tensors, arch `qwen35moe`,
256 experts/layer, 8 used/token, 41 MoE layers (blk.0-40), FF 512, n_embd 2048. A q4_K layer's expert
blob is 3 x 589,824 B per expert (gate/up/down at 2048x512 and 512x2048); the engine's own load line
reports the hybrid arena: 18.66 GiB.

| file | by_type() histogram | expert gate/up | expert down |
|---|---|---|---|
| Q4_K_M (21,780,313,248 B) | Q4_K 289, Q6_K 94, F32 310, Q8_0 60 | Q4_K x41 | Q4_K x20 (layers 5,6,8,9,11,12,14,15,17,18,20,21,23,24,26,27,29,30,32,33), Q6_K x21 |
| Q4_K_S (20,433,712,288 B) | Q4_K 338, Q6_K 31, Q5_K 14, F32 310, Q8_0 60 | Q4_K x41 | Q4_K x36 (layers 5-40), Q5_K x5 (layers 0-4) |
| Q5_K_S (24,598,656,160 B, baseline) | Q5_K 352, Q6_K 31, F32 310, TQ1_0 60 | Q5_K x41 | Q5_K x41 |

Q4_K_S is a mixed dynamic file on five layers (q4_K/q5_K — a pre-existing supported pair); Q4_K_M mixes
q4_K/q6_K (also pre-existing) on 21 layers with q4_K/q4_K (the new pair) on 20. Every layer of both files
is now covered by `native_expert_supported()`.

## Parity

Synthetic blobs (GPU grouped kernels + CPU AVX2 pool vs ggml float reference, `--synthetic`, the
model's true shapes n_embd 2048 / FF 512 — blob sizes then match the real per-layer blobs, e.g.
q4_K/q4_K 1,769,472 B = layer 20's blob):

| pair | cpu rel | gpu rel | cpu-gpu |
|---|---|---|---|
| q4_K/q4_K (new) | 1.94e-02 | 1.29e-02 | 2.19e-02 |
| q4_K/q5_1 | 1.41e-02 | 1.21e-02 | 1.44e-02 |
| q4_K/q8_0 | 1.41e-02 | 1.29e-02 | 1.60e-02 |
| q5_K/q8_0 | 1.46e-02 | 1.23e-02 | 1.42e-02 |
| q8_0/q8_0 | 1.23e-02 | 1.23e-02 | 1.04e-07 |
| q4_K/q5_0 | 1.46e-02 | 1.31e-02 | 1.72e-02 |
| q5_0/q8_0 | 1.26e-02 | 1.26e-02 | 9.73e-08 |
| q4_0/q4_0 | 1.27e-02 | 1.27e-02 | 9.92e-08 |
| q4_0/q4_1 | 1.27e-02 | 1.27e-02 | 3.23e-04 |
| q6_K/q8_0 | 1.42e-02 | 1.33e-02 | 1.56e-02 |

`native_expert_parity: 0 failures` (exit 0) for all ten pairs; the GPU dequantizer is bit-identical to
ggml's `to_float` (0 of 3,932,160 values differ) and the GPU decode-once path is bitwise equal to the
per-entry kernels in every pair.

Real layer blobs (same harness, GGUF mode, layers from each file):

- Q4_K_M layers 0/1/2/3/40 (q4_K/q6_K) and 20 (q4_K/q4_K): gpu rel 9.95e-03 .. 1.22e-02, 0 failures
- Q4_K_S layers 0/1 (q4_K/q5_K) and 20/40 (q4_K/q4_K): gpu rel 9.95e-03 .. 1.22e-02, 0 failures

`dequant_wide_parity` (Q4_K/Q5_K/Q6_K/IQ4_XS, 360 cases, bitwise wide-vs-narrow, sane and raw-byte
blocks): `360 cases, OK (bitwise)`, exit 0 — unchanged by the patch.

Regression at the whole-model level: the pinned fp32 solo gate (Q5_K_S, `--expert-slots 5`, 10 parity
prompts, 128 greedy tokens) with the NEW binary is bit-identical to the OLD binary's JSON:
**identical: 10 of 10** (p04 16 tok, p06 90, p07 68, p09 23 — the stop/length cuts land on the same
tokens as before).

`STRATA_Q36_VERIFY=1` on the Q4_K_M decode path (the old kernel beside the new one, bit for bit, on
live activations): **6103 comparisons, 0 mismatches**, exit 0 — the same comparison count the KV task's
VERIFY runs reported, now over the q4_K/q4_K layers' activations.

## Engine load (Q4_K_M)

    strata-q36: ... 753 tensors (layout checked), 1.72 GiB on the GPU in 15.8 s
    strata: K-quant prompt kernels from .../libstrata_kq.so (STRATA_MMQ_KQ=1)
    strata-q36: prompt experts on MMQ (int8)
    strata-q36: context 8192 cells, prompt chunk 512, KV cache fp32, MTP block loaded, 3.57 GiB of VRAM free
    strata-q36: hybrid experts: 25 of 256 per layer in VRAM (1.82 GiB), all 18.66 GiB in pageable host memory ...

Coherence (the solo gate's 10 greedy generations per file, decoded): prose ("The salt spray had long
since bleached Elias's skin to the color of old parchment..."), code (a doubly linked list Node class),
arithmetic ("To solve the expression $17 \times 23 + 144 / 12$..." — identical digits on both files),
explanations (refrigerator/heat-pump analogy). Both files generate coherent, on-topic text.

MMQ: **engaged for both Q4_K files** ("prompt experts on MMQ (int8)"). The gate
(q36_engine.cu:1554-1560) ANDs `MMQ::supported` + `MMQ::fits` over every layer and the MTP block;
Q4_K and Q5_K are both K-quants under `STRATA_MMQ_KQUANTS`, and the strata_kq DSO is built
(`STRATA_KQ_DSO=1`), so `kq_ok()` is true without any env var. Enabling MMQ for Q4_K down therefore
needed **no separate work** — the prompt path never dropped to the non-MMQ fallback.

KV cache fp32 default untouched (the load line prints `KV cache fp32`; the serving config's int4 is a
serve.sh default, unchanged from the KV task).

## llama.cpp text parity (same file, greedy, 128 tokens)

llama.cpp built from source with CUDA 12.6 (`-DCUDAToolkit_ROOT=/usr/local/cuda-12.6`; the box's first
configure probed a Windows-side CUDA 13.3 on the inherited PATH and died on cudart), `llama-server` +
`llama-cli` binaries. The task's `-fa 1` is spelled `-fa on` in current llama.cpp; run with
`-ngl 99 -ncmoe 41` (all 41 MoE layers' experts in host RAM, the rest on GPU), temperature 0.

Protocol: the 10 parity prompts are **token ids**; llama.cpp `/completion` took them as an id array (no
fallback to text was needed), so both engines start from identical ids. llama.cpp's generated ids came
from `/tokenize` of its own text (round-trip loses exactly the stop token: 16→15, 113→112, 68→67, 24→23
— consistent with generation stopping on EOS).

Per-prompt match (engine ids vs llama.cpp ids, common prefix / min length):

| prompt | engine | llama.cpp | common | ratio | first differing |
|---|---|---|---|---|---|
| p0 | 128 | 128 | 65 | 0.508 | 65 |
| p1 | 128 | 128 | 25 | 0.195 | 25 |
| p2 | 128 | 128 | 128 | 1.000 | — |
| p3 | 128 | 128 | 128 | 1.000 | — |
| p4 | 16 | 15 | 15 | 1.000 | — |
| p5 | 128 | 128 | 6 | 0.047 | 6 |
| p6 | 124 | 112 | 6 | 0.054 | 6 |
| p7 | 70 | 67 | 47 | 0.701 | 47 |
| p8 | 128 | 128 | 14 | 0.109 | 14 |
| p9 | 22 | 23 | 11 | 0.500 | 11 |

**Overall match ratio: 0.511** (10 prompts).

Every divergence is a synonym/formatting near-tie at the flip point, decoded at the first differing
token: p0 `' cycle'`(10458) vs `' loop'`(6136) after `' life was a'`; p1 `':'` vs `'=None'` in a
constructor signature; p5 `' **'` vs `' the'` after `' key differences between'`; p6 `' noble'` vs
`' families'` after `' from feuding'`; p7 `' Fiction'` vs `','` after `'    "Classic'`; p8 `' Ded'` vs
`' Explanation'` in a heading; p9 `' on'` vs `' in'`. Two prompts (p2, p3) are bit-identical for the
whole 128-token budget; coherent, on-topic text on both sides for all ten (p2 is the same arithmetic
problem, both engines solve it with the same digits). The pattern is the expected ulp-cascade between
two different numeric paths — llama.cpp computes experts in fp32 on CPU with an f16 KV, this engine
decodes experts in fp16 on the GPU with int8 MMQ prompt rows — not a layout or tokenizer mismatch:
identical prompt handling, identical tokenization, identical stop behavior.

## Speed / memory (same box, same prompts, greedy)

Serve defaults both files: KV=int4, MTP 2, CPU_THREADS 0, SAMPLING `{"presence_penalty": 0}` so the
MTP drafting engages (the KV task's greedy-sampler speed config). bench cells: one warmup round, one
measured round; decode = output tokens/window; the measured round's ttft is prefix-cache-primed, so
**cold prefill is quoted from the warmup round's ttft**. Run-to-run spread on the anchor config across
three repeats: 48.1 / 45.8 / 44.1 tok/s (±5%), so treat single cells as ±10%.

Baseline cells, default placement (25 slots, MMQ on), 2048 output tokens:

| cell | decode tok/s | cold prefill tok/s | VRAM peak | RAM peak |
|---|---|---|---|---|
| **Q4_K_M** empty (1 tok) | **38.5** | — | 6.90 GiB | 21.4 GB |
| **Q4_K_M** 4K (4096) | **26.9** | 153 (26.8 s) | 6.90 GiB | 22.5 GB |
| **Q4_K_M** 32K (32768) | **22.6** | 173 (189 s) | 6.91 GiB | 22.5 GB |
| Q5_K_S empty | 31.9 | — | 6.89 GiB | 24.8 GB |
| Q5_K_S 4K | 23.4 | 153 (26.8 s) | 6.89 GiB | 24.9 GB |
| Q5_K_S 32K | 21.9 | 173 (189 s) | 6.91 GiB | 24.8 GB |

The Q4_K file at the same config: empty **+21%** (38.5 vs 31.9), 4K decode +15% (26.9 vs 23.4), 32K
decode +3% (22.6 vs 21.9), cold prefill unchanged (the MMQ prompt rows read 589,824 vs 720,896 B per
role — within noise), and system RAM down 3.4 GB (21.4 vs 24.8 GB empty — 18.66 vs 21.14 GiB of
experts, the reason for this change on a 26 GB box).

Tuned-config push (serving knobs only; no code change): `--expert-slots` (the ledger:
q36_engine.cu:3250-3259 prints need/free — ~74.6 MiB per slot over 41 layers, plus the ~995 MiB MMQ
staging pair when the MMQ prompt path is on), `STRATA_Q36_NO_MMQ=1` (frees the staging pair; decode
runs on slots + the CPU pool either way), `CPU_THREADS` (8 > 0 > 10; 12 was known harmful from the KV
task), MTP (2 stays; 3 loses).

| config (Q4_K_M, empty decode) | decode tok/s | repeats |
|---|---|---|
| slots 25, MMQ, CT 0 (serving default) | 38.5 | — |
| slots 35, MMQ, CT 0 | 45.0 | — |
| slots 36, MMQ, CT 0 | 42.6 | — |
| slots 50, MMQ off, CT 0 | 45.8 | 45.8 |
| **slots 50, MMQ off, CT 8** | **48.1** | 45.8, 44.1 |
| slots 50, MMQ off, CT 10 | 37.2 | (23.2 outlier not repeated) |
| slots 50, MMQ off, MTP 3 | 42.3 | MTP 2 stays |

The prompt-path cost of turning MMQ off, measured cold: 4K prefill 89 tok/s vs 153 with MMQ — 1.7×
slower. The engine's guard fixes each context's slot ceilings from need/free
(q36_engine.cu:3250-3259): 32K caps at 36 slots with MMQ on (45 refused: 4387 vs 3764 MiB) and 50 with
MMQ off (55 refused: 4136 vs 3808); 64K caps at 47 slots with MMQ off (50 refused: 3763 vs 3550) and
33 with MMQ on.

Long-context cells at those ceilings:

| cell | config | decode tok/s | cold prefill | VRAM peak | RAM peak |
|---|---|---|---|---|---|
| Q4_K_M 32K | MMQ off, slots 50, CT 8 | **24-25** (23.9, 25.2) | 120 (272 s) | 7.56-7.59 GiB | 22.2 GB |
| Q4_K_M 32K | MMQ on, slots 25, CT 0 | 22.6 | 173 (189 s) | 6.91 GiB | 22.5 GB |
| Q4_K_M 64K | MMQ off, slots 47, CT 8 | 18.5 | 119 (549 s) | 7.60 GiB | 22.3 GB |
| Q4_K_M 64K | MMQ on, slots 33, CT 8 | 17.5 | 175 (375 s) | 7.63 GiB | 22.3 GB |
| Q4_K_M 64K | MMQ on, slots 25, CT 0 (serving default) | 18.5 | 168 (389 s) | 7.01 GiB | 22.4 GB |
| Q5_K_S 64K | MMQ on, slots 25, CT 0 (serving default) | 19.4 | 146 (450 s) | 6.95 GiB | 24.8 GB |

One reproducible pathology worth recording: MMQ on with slots 36 at 32K decodes at **6.1 tok/s** while
prefill stays 172 — reproduced twice (6.13, 6.14), VRAM peak 7.65 GiB: the guard passed with only
48 MiB of margin and the decode-time scratch then runs at the edge. The same slots are fine empty
(42.6). Keep MMQ configs at the default 25 slots for long contexts, or turn MMQ off when decode is
what matters. Unconfirmed static reading of the mechanism (the margin edge); the numbers are measured.

**Targets vs achieved** (the ask: empty ~60, 32K ~30, 64K 25-30):

- empty: **44-48** of 60 (73-80%) — 38.5 at the serving default, 44-48 tuned.
- 32K: **24-25** of 30 (80-84%) — 22.6 default, 24-25 tuned.
- 64K: **18.5-19.4** of 25-30 (62-73%) — and the Q5_K_S file does the same 19.4 at the same config, so
  the 64K decode number is box-bound (bandwidth + slots ceiling), not file-bound. The Q4_K file gives
  the same decode with 2.4 GB less RAM and ~15% faster cold prefill.

## MMQ status and what remains for Q4_K downs

MMQ engaged; nothing remains for the prompt path. The native decode path now covers q4_K/q4_K; the
mixed pairs (q4_K/q5_K, q4_K/q6_K) were already covered.

## Not tested

- **128K context on the Q4_K files**: 18.66 GiB of experts + 2.9 GiB of int4 KV fits the box only
  engine-only (the KV task ran 128K engine-level on the Q5_K_S file); the server + bench client add
  ~2-3 GB, so a served 128K cell was not attempted.
- **Concurrency > 1**: every bench cell ran one request; the parallel/multi-request path is untested on
  the Q4_K files.
- **Vision / mmproj**: the engine's vision path (`mmproj-BF16.gguf`) is untested with Q4_K experts.
- **Other models' Q4_K layouts**: the synthetic parity ran at Qwen3.6's shapes (n_embd 2048, FF 512 —
  and at Flash-Next's hidden 2560 in the default-shape run); Flash-Next's FF 640 can never take a
  Q4_K down (`n_ff % 256 != 0` refuses in `native_expert_supported`), so the pair is Qwen3.6-shaped.
  Q4_K gate/up with Q8_0/Q5_1/IQ4_XS down is covered by the unchanged synthetic pairs and the 10-of-10
  bit-identical Q5_K_S gate.
- **HIP / SYCL / Metal builds**: the change touches only the CUDA table in `iq_kernels.cu`; the other
  backends are untested.
- **Q4_K_S at long contexts**: only its solo gate and real-file parity ran; no bench cells.
- **The 6.1 tok/s pathology's mechanism**: measured twice, but the VRAM-margin explanation is an
  unconfirmed static reading (the engine has no instrumentation that names the failing allocation).
- **Draft acceptance counts** with the Q4_K files: the bench reports aggregate tok/s; per-step
  accepted/1 counts were not extracted.

