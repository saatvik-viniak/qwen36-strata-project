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
load the same weights.

Which quant runs: `Q5_K_S`, `Q5_K_M`, `Q6_K` and `Q8_0`. `Q4_K_S`, `Q4_K_M`, `Q3_K_*` and `BF16` are refused —
their expert `down_proj` type is not in the kernel tables (`STRATA_D_FMTS` in `src/kernels/cuda/iq_kernels.cu`),
and the engine says which layer failed instead of running it wrong. Q5_K_S (24.6 GB) is the default for a 26 GB
machine. `download_model.sh` fetches the GGUF.

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
| `CAMPAIGN.md` | How to create a campaign for this project, and the two limits that must be set. |
| `preflight.sh` | Runs every step the judge will take, by hand, before a campaign exists. |
| `serve.sh` | The serving entry point. Writes the server config and starts `serve.server` with `--engine strata`. |
| `build_kit.sh` | Compiles `strata` here and stages `build/` (engine binary + server + this tree) for the judge. |
| `setup_rig.sh` | Run once on the rig: toolchain, `/opt/strata/venv`, first compile. |
| `download_model.sh` | Fetches the published `qwen35moe` GGUF instead, if you would rather not convert. |
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
