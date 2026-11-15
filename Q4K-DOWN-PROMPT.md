# Goal: make Q4_K expert down-projections load in Strata's Qwen3.6 engine path

## Objective
Two things, in this order:

1. **Verify** whether a given GGUF already loads (a mixed "dynamic" quant can pass as-is).
2. **Patch** `src/qwen35` so that Q4_K **expert down-projections** are accepted by the native expert kernels, so
   Q4_K_S / Q4_K_M files (20-22 GB) run on this engine, with text parity against llama.cpp on the same file.

Do not touch anything else. No KV-cache work, no speed tuning.

## Why it fails today
The engine checks each MoE layer against two separate type tables in `src/kernels/cuda/iq_kernels.cu`:

```
STRATA_GU_FMTS(X) X(16) X(17) X(18) X(21) X(22) X(23) X(29) X(42) X(12) X(13) X(14) X(6) X(2) X(3) X(8) X(40) ...
STRATA_D_FMTS(X)  X(20) X(23) X(42) X(7) X(6) X(2) X(3) X(8) X(13) X(14) X(40) ...          <- no X(12)
```

`12` is `GGML_TYPE_Q4_K`. Gate/up accepts it; **down does not**. On a Q4_K_M file the engine loads 17 GB of dense
weights and then refuses:

```
strata-q36: blk.5.experts are Q4_K/Q4_K, which the native expert kernels do not take
```

`native_expert_supported()` in `iq_kernels.cu` requires **both** types to be in their list, so the fix is the table.

## What already exists (verify before you write new code)
Everything a Q4_K down path needs is already in the tree:
- `template<> struct Fmt<12>` with `qk = 256`, `ipb = QI4_K / VDR_Q4_K`, `dot = vec_dot_q4_K_q8_1` (~line 816)
- `vec_dot_q4_K_q8_1` and its vmmq implementation (~lines 330, 381)
- `dq_q4_k` device dequantiser and `case 12:` in the dequant switch (~lines 3118, 3327)
- `iq_row_bytes()` `case 12: (n / 256) * sizeof(block_q4_K)` (~line 5341)
- `STRATA_MMVQ_FMTS` already contains `X(12)`
- `block_bytes()` / `row_bytes()` in `q36_engine.cu` use `strata::block_geometry()`, which knows Q4_K
- `native_expert_layout()`, `native_expert_layout_nib()` and the grouped kernels are templated from the same macros,
  so adding the entry instantiates them

So the change is the table, not a new kernel. If you find a place where Q4_K is missing beyond the table, say so
with the symbol and line rather than working around it.

## Step 1 — verify the file you have (do this first)
The file may already work if it is a mixed quant (gate/up Q4_K, down Q6_K), which is common in Unsloth "UD"
dynamic quants and is why the build enables `STRATA_Q6K_EXPERTS`.

```sh
cd ~/qwen36-strata-project
/opt/strata/venv/bin/python - <<'PY'
import sys; sys.path.insert(0, "tools")
from gguf_reader import GGUFFile
p = "/models/qwen36-heretic/<file>.gguf"
g = GGUFFile(p)
print("arch:", g.metadata.get("general.architecture"))
print("types:", g.by_type())
for t in g.find("blk.5.ffn_gate_exps"): print("gate/up:", t.type_name)
for t in g.find("blk.5.ffn_down_exps"): print("down:   ", t.type_name)
PY
```

| gate/up | down | Action |
| --- | --- | --- |
| Q4_K | Q6_K / Q5_K / Q8_0 / IQ4_XS | **already compatible** — just run it, skip to Step 4 |
| Q4_K | Q4_K | patch, Step 2 |
| Q3_K anything | any | out of scope: `X(11)` is in neither list and Q3_K downs would need the same treatment plus a Q3_K dot path; report, do not attempt |

## Step 2 — the patch
In `src/kernels/cuda/iq_kernels.cu`, add `X(12)` to **both** `STRATA_D_FMTS` branches, keeping their existing order
and the comment style, e.g.:

```c
#ifdef STRATA_Q6K_EXPERTS
#define STRATA_D_FMTS(X) X(20) X(23) X(42) X(7) X(6) X(2) X(3) X(8) X(12) X(13) X(14) X(40) X(144) X(146) X(147) X(148) X(149)
#else
#define STRATA_D_FMTS(X) X(20) X(23) X(42) X(7) X(6) X(2) X(3) X(8) X(12) X(13) X(40) X(144) X(146) X(147) X(148) X(149)
#endif
```

Add one line of comment saying why (`Q4_K gate/up already allowed; Qwen3.6 Q4_K_S/M store the expert down
projections as Q4_K too`). Do not reorder existing entries.

Then rebuild:

```sh
JOBS=1 ./build_kit.sh
```

Expect compile time to grow: one more template instance per kernel, per architecture. If the build fails on an
instantiation, read the error: it will name the missing `Fmt<12>` member, which means an additional template list
needs the entry too — find it, add it, and note it in the change note.

## Step 3 — engine-level checks
```sh
GGUF=/models/qwen36-heretic/<the Q4_K file>.gguf
./out/strata --native "$GGUF" --max-context 8192 --bench-pp 8 --bench-tg 1
```
- The load must pass the expert check and print its memory line.
- Watch `nvidia-smi` and `free -m` while it loads: 22 GB of weights is the point of this change.
- If it fails with a different layer/type, stop and report the exact message; do not widen more tables blindly.

## Step 4 — correctness, in increasing strictness
1. **Dequant parity.** `iq_dequant_f16(12, ...)` must match llama.cpp's `dequantize_row_q4_K` (available in
   `third_party/strata-ggml/ggml/src/ggml-quants.c`). There are existing parity harnesses under `src/kernels/`
   (e.g. `native_expert_parity`, `dequant_wide_parity`) — use the one that already enumerates types from
   `native_expert_supported()`, so Q4_K downs are covered once the table allows them.
2. **Expert kernel parity.** `native_expert_grouped` for `(gu=12, down=12)` against a reference fp32 matmul on the
   same quantised weights: max relative error must be inside the tolerance the other K-quant cases use (report the
   number; do not loosen the tolerance to pass).
3. **Same-file text parity against llama.cpp.** Run the same GGUF in llama.cpp with greedy decoding and a fixed
   prompt (its own `-ncmoe` split, `-fa 1`), and in this engine with the same prompt and `temperature 0`, 128
   tokens. Report the match ratio and the first differing token. A correct Q4_K path should be near-identical;
   a wrong one produces different-but-plausible text, which is exactly what this step catches.
4. **The engine's own gates**: `tools/qwen35/q36_solo_gate.py` and `q36_cmp_gate.py`, and
   `STRATA_Q36_VERIFY=1` on the decode path.

## Step 5 — measure and report
On the same box, same prompts, greedy:
- decode tok/s and prefill tok/s at 4K and 32K prompts, for the Q4_K file and for the Q5_K_S file you already run;
- peak VRAM and system RAM for each (this is the reason to do the change at all: 22 GB vs 24.6 GB, on a 26 GB box);
- whether the prompt path used MMQ. `MMQ::supported(type)` / `MMQ::fits()` gate it in `q36_engine.cu` (~line 1377);
  if Q4_K down is not supported there, `use_mmq` turns false for the whole model and prompts get slower. That is
  acceptable for correctness, but report it, and say whether enabling MMQ for Q4_K down is a separate piece of work.

## Acceptance criteria
1. A Q4_K/Q4_K file loads and generates coherent text; no expert-type refusal.
2. Q4_K gate/up with Q5_K/Q6_K/Q8_0/IQ4_XS down still behaves exactly as before (no regression: same text, same
   memory).
3. Dequant and expert-kernel parity pass at the same tolerances as the other K-quants, with the numbers reported.
4. Greedy text on the fixed prompt matches llama.cpp on the same file; report the ratio.
5. fp32 KV default untouched; no change to the model file, tokenizer, sampling or benchmark.
6. Report: peak VRAM, system RAM, decode/prefill at 4K and 32K, MMQ on or off, and what you did not test.

## Deliverable
A patch to `src/kernels/cuda/iq_kernels.cu` (plus any other template list the compiler proves is needed), and a
note with:
- the table change and why Q4_K downs were excluded;
- which file you tested, its `by_type()` histogram and expert types;
- parity numbers (dequant, expert kernel, llama.cpp text match);
- the speed and memory table, Q4_K vs Q5_K_S;
- whether MMQ engaged, and what remains to enable it for Q4_K downs.

## Failure handling
- Load still refused with the same message → the table edit did not reach the build (check `out/strata` timestamp)
  or a second table gates it; find the exact check and quote it.
- Coherent but wrong text → the down path is using the gate/up stride or the wrong row bytes; check
  `native_expert_layout()`'s `down_off` and `d_row` for type 12.
- Crash inside the grouped kernel → a template instance exists for gate/up but not down; the compiler or the
  kernel's type switch will name it.
- Much slower prompts → MMQ did not engage; measure the non-MMQ cost and report it instead of forcing the path.
