# qwen36-strata project

The candidate repository for the `qwen36-strata` kit. It is the [Strata](https://github.com/Niko1221/Strata)
inference engine at commit `13eedf552417a6a791a7d13c6597e24300ee3a09` plus the scripts below. Strata is MIT
licensed; `LICENSE` is its licence.

**Qwen3.6-35B-A3B is the model and Strata is the engine. Neither is changed.** Everything else in this tree,
including the engine's kernels under `src/`, is fair game for the optimizing agent.

**The first job is not a flag: `INSTRUCTIONS.md` asks for an int4 KV cache in `src/qwen35` before any tuning,** because
the engine's fp32 cache is what makes 128K and the 262,114-token context impossible on 8 GB.

## What the engine runs

Strata has a dedicated path for this family (`src/qwen35`). It switches to it when the GGUF's architecture is
`qwen35moe`, reads the file in place, keeps every routed expert it can in VRAM and computes the rest on the CPU,
and drafts with the MTP block inside the GGUF.

llmfan46 publishes this fine-tune already in that shape, with the MTP block preserved:

```
llmfan46/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-GGUF
  architecture: qwen35moe      context_length: 262144
  Q3_K_M  Q4_K_S  Q4_K_M  Q5_K_M  Q6_K  Q8_0  BF16  + mmproj-BF16
```

So the GPTQ-Int4 checkpoint is **not** the artifact this engine wants, and no quantisation patch is needed to
load the same weights. `download_model.sh` fetches the GGUF.

## The wall: KV cache is fp32

The qwen35 path allocates fp32 K and V for the 11 attention-bearing layers (10 full-attention layers plus the
MTP block), 2 KV heads, head dim 256:

```
11 x 2 x 2 x 256 x 4 B = 45,056 B/token = 45 KB/token
```

| Context | KV cache |
| ---: | ---: |
| 32,768 | 1.41 GiB |
| 65,536 | 2.82 GiB |
| 131,072 | 5.64 GiB |
| 262,114 | 11.3 GiB |

The engine allocates it at start-up and refuses a context the card cannot hold. On an 8 GB card that makes 128K
and 262K unreachable until the KV cache is quantised — which is engine work, and **the first task in
`INSTRUCTIONS.md`**. int4 brings the same table to 5.6 KB/token: 128K = 0.70 GiB, 262,114 = 1.41 GiB.

* `k_kv_f16` in `src/qwen35/q36_engine.cu` already converts f32 KV to half precision for one path; a full f16
  cache halves the table above and makes 128K fit.
* int8 or 4-bit KV with per-token scales makes 262,114 fit and is the real fix.

## Files

| File | What it is |
| --- | --- |
| `INSTRUCTIONS.md` | The optimizing agent's brief. Job 1: int4 KV cache in `src/qwen35`. |
| `serve.sh` | The serving entry point. Writes the server config and starts `serve.server` with `--engine strata`. |
| `build_kit.sh` | Compiles `strata` here and stages `build/` (engine binary + server + this tree) for the judge. |
| `setup_rig.sh` | Run once on the rig: toolchain, `/opt/strata/venv`, first compile. |
| `download_model.sh` | Fetches the published `qwen35moe` GGUF instead, if you would rather not convert. |
| `prepare_model.sh` | Converts a local GPTQ-Int4 checkpoint into the `qwen35moe` GGUF the engine reads (dequant → GGUF → quantize). |
| `cuda_env.sh` | Finds `nvcc`; WSL keeps the toolkit in a versioned folder that is not on `PATH`. |
| `src/`, `include/`, `cmake/`, `serve/` | Strata. `src/qwen35/` is the engine path for this family. |

## Run it by hand

```sh
./setup_rig.sh
./download_model.sh Q4_K_M /models/qwen36-heretic

export MODEL_GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q4_K_M.gguf
export MAX_CONTEXT=32768
export PORT=30000
./serve.sh
curl -s http://127.0.0.1:30000/v1/models
```

`serve.sh` uses `build/strata` when it exists (what the kit stages) and `out/strata` otherwise (after
`build_kit.sh` on the rig).

## Using a checkpoint you already have

If the checkpoint on disk is a HF GPTQ-Int4 directory (for example
`/models/qwen36-35b-a3b-gptq-int4`), it is not something the engine can read: Strata's Qwen3.6 path reads one GGUF
with architecture `qwen35moe`. Convert it once, on this machine:

```sh
./prepare_model.sh /models/qwen36-35b-a3b-gptq-int4 Q4_K_M /models/qwen36-heretic
export MODEL_GGUF=/models/qwen36-heretic/qwen36-heretic-Q4_K_M.gguf
```

What it does: GPTQModel dequantizes the packed tensors to a dense bf16 directory, llama.cpp's converter writes a
bf16 GGUF carrying architecture `qwen35moe`, and `llama-quantize` writes the final file in the quant you name.
It is a one-time job of roughly 1-3 hours on this CPU, and it wants about four times the packed model's size in
free disk (~165 GB) because the dense copy and the bf16 GGUF both exist at once.

One limit worth knowing before you spend that time: this checkpoint has **no MTP block** (the tensor index has no
`mtp` entry), so a GGUF made from it also has none, and the engine turns drafting off by itself — you lose the
roughly 1.6x that the MTP drafter gives a solo request on a small card. The published
`…-Native-MTP-Preserved-GGUF` was made from the MTP-preserving version of the same fine-tune and keeps it. Both are
the same fine-tune; only the drafter differs.

`prepare_model.sh` checks the result and prints the architecture and whether the MTP block is present, so a bad
conversion is caught before a campaign runs.

## Knobs that matter for speed

Engine settings are the config's `args` in `serve.sh`:

| Setting | Effect |
| --- | --- |
| `--max-context` | KV allocation. The biggest lever on what fits. |
| `--prefill` | Prompt chunk (auto, or 512/1024/2048/4096). Larger chunk = faster prompt, fewer expert slots. |
| `--mtp N` | Drafts per step from the GGUF's MTP block (0-7). |
| `--cpu-threads` | CPU expert and GEMM pool. |
| `--expert-vram` / `--expert-slots` | Expert placement between the card and RAM. |
| `--hybrid-rows` | Rows per hybrid expert block. |

Environment switches the engine reads: `STRATA_Q36_CHUNK`, `STRATA_Q36_READ_WINDOWS`, `STRATA_Q36_NO_MMQ`,
`STRATA_Q36_STREAM_ALL`, `STRATA_Q36_KEEP_PACKED`, `STRATA_Q36_FIXED_SLOTS`, `STRATA_Q36_OLD_KERNELS`,
`STRATA_Q36_VERIFY` (the last two are the bit-for-bit gates for kernel changes).

## Rebuilding after an edit

```sh
./build_kit.sh          # or: cmake --build out --target strata -j "$(nproc)"
```

`STRATA_Q36_VERIFY=1` runs the old kernel beside a new one on the same activations and compares them bit for bit;
`test/qwen35` gates in `tools/qwen35/` do the same through the serve protocol.
