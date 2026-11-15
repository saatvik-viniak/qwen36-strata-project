# Instructions for the optimizing agent

The model is `Qwen3.6-35B-A3B` (the llmfan46 heretic fine-tune as a `qwen35moe` GGUF). The engine is Strata in
this tree. Both are fixed. Everything else — `serve.sh`, the engine's C++, its CUDA kernels, its cache layout —
may be changed.

The engine is compiled from this tree at build time, so an edit to `src/` is a real candidate. Every change is
judged by the hidden benchmark on the same four workloads, so measure, do not assume.

## Job 1, before any speed tuning: an int4 KV cache

The qwen35 path (`src/qwen35/q36_engine.cu`) stores K and V as **fp32**, allocated once at start-up for the whole
context:

```c
// alloc_session(), for each attention layer and for the MTP block:
ss.kc.push_back(dalloc((size_t) g.n_head_kv * ctx * g.head_dim));
ss.vc.push_back(dalloc((size_t) g.n_head_kv * ctx * g.head_dim));
```

With 11 attention-bearing layers, 2 KV heads and head dim 256 that is **45,056 bytes per context token**:

| Context | fp32 KV | int8 KV | int4 KV |
| ---: | ---: | ---: | ---: |
| 32,768 | 1.41 GiB | 0.70 GiB | 0.35 GiB |
| 65,536 | 2.82 GiB | 1.41 GiB | 0.70 GiB |
| 131,072 | 5.64 GiB | 2.82 GiB | 1.41 GiB |
| 262,114 | 11.3 GiB | 5.64 GiB | 2.82 GiB |

On the 8 GB card the fp32 cache is what blocks 128K and the 262,114-token context entirely. **Adding int4 KV is the
first task, not a tuning idea.** Until it lands, the campaign measures `ctx0`, `ctx32k` and `ctx64k`; `ctx128k` and
the full 262,114 context are blocked on this work.

### What to do

1. Add an opt-in flag, `--kv int4` (and `int8` / `f16` while you are there), defaulting to the current `fp32` so
   the existing path stays byte-identical. `--kv` is already a Strata flag name elsewhere in the project; here it
   is the qwen35 engine's own option parsed in `strata::qwen35::run`.
2. Store K and V packed: 4-bit nibbles with a scale (and, if you want it, a zero point) per KV head per group of
   32 or 64 cells. Both tensors, and the MTP block's, use the same layout.
3. Thread it through both readers of the cache:
   * decode and verify: `k_attn_part` (search `const float* q, const float* kc, const float* vc`) reads rows
     `ctx` apart with `HD == 256`, including the batch row-selection path (`rs.kc` / `rs.vc`);
   * prompt: `k_kv_f16` already converts a window of cells to compact halves — make the same staging point dequant
     int4 into the float workspace the prompt kernels take.
4. Round-trip correctly at the boundary: the last partial group, positions past the prompt, and a batch slot's
   copied start (`select()` and the row tables) all have to carry the packed rows, not a stale float copy.
5. Correctness first, speed second. A dequant-to-float staging window is an acceptable first version; fusing the
   dequant into `k_attn_part` and the prompt attention kernels is the follow-up that recovers the bandwidth you
   spend.

### Gates a KV patch must pass

* `STRATA_Q36_VERIFY=1` — runs the old kernel beside the new one on the same activations and compares bit for bit.
* `STRATA_Q36_OLD_KERNELS=1` — the previous kernels, for an A/B on the same build.
* `tools/qwen35/q36_solo_gate.py` and `q36_cmp_gate.py` — the parity prompts through the serve protocol.
* The campaign's own check: the same greedy text as the fp32 baseline at `ctx0` / 32K / 64K, `match_rate >= 0.95`
  on every cell, and peak VRAM under 7.9 GiB.
* `--max-context 131072` must start and answer; then `--max-context 262114`.

### Done

`MAX_CONTEXT=262114` with `--kv int4` starts on the 3070, the `ctx128k` cell runs inside the same 7.9 GiB, and the
answers match the fp32 baseline. Paste the measured start-up KV allocation and the per-cell numbers in the change
note.

## After that: speed

One change per trial, measured on all selected cells, with a negative control kept:

* **KV**: group size, scale dtype, fused dequant, keeping hot rows in fp32.
* **Placement**: `--expert-vram`, `--expert-slots`, `--hybrid-rows`, `STRATA_Q36_KEEP_PACKED` — how many experts
  sit on the card versus RAM is the largest single lever in the hybrid mode.
* **Prompt chunk**: `--prefill` 512 / 1024 / 2048 / 4096, `STRATA_Q36_CHUNK`, `STRATA_Q36_READ_WINDOWS`.
  Bigger chunk reads the prompt faster and costs expert slots.
* **Drafting**: `--mtp 0..7`, `--batch-mtp`.
* **Threads**: `--cpu-threads`, CPU pool affinity.
* **Kernels**: `STRATA_Q36_NO_MMQ`, `STRATA_EXPERT_V2K`, the MMQ K-quant prompt kernels, the Q8_0 packed decode
  copy (`STRATA_Q8_PACKED`), fused QK-norm/rope, the GDN recurrence.
* **Graphs**: `--no-graph` is the control; capture shape work is a candidate.

## Do not change

The model file, the tokenizer, the benchmark, the timer, the sampling (greedy), the prompt or output lengths,
the hardware, or the workload's concurrency. The weights are whichever `qwen35moe` GGUF the rig was given — the
published file or a conversion of the local GPTQ-Int4 checkpoint by `prepare_model.sh`. Do not swap it, re-quantize
it, or convert it again; a different file is a different candidate. No cached answers, no skipped tokens, no output
trimming. Peak VRAM per GPU stays under 7.9 GiB and system RAM under 24 GiB; an OOM is a failed trial, not a
tradeoff.

Follow Strata's own contribution rules for anything you keep: a new feature is opt-in, and the default path
stays byte-identical to the last behaviour unless a measurement on this machine says otherwise.
