# State as of 2026-11-15

The durable record of this project. Read this first after any compaction, restart or handover.

## Where things are

| Thing | Value |
| --- | --- |
| Project repo | `https://github.com/saatvik-viniak/qwen36-strata-project` |
| Latest commit | `ddb4685` (adds `INT4-KV-PROMPT.md`) |
| Kit repo | `https://github.com/saatvik-viniak/qwen36-strata-kit` |
| Latest kit commit | `dd25c45` (`MAX_CONTEXT=auto`, chunk 1024, 15-min cells) |
| Rig | `windows-rig` — RTX 3070 8 GB, 26 GB RAM, WSL2 `Spooky`, user `dmin` |
| Model | `/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf` |
| Tokenizer | `/models/qwen36-heretic/tokenizer/` (from `tools/strata_tokenizer.py`) |
| Bench tokenizer | `/models/qwen36-tokenizer/` |
| Python | `/opt/strata/venv/bin/python` (Strata deps + `huggingface_hub[cli]` + `tools/requirements-bench.txt`) |
| Engine | `out/strata` and `build/strata` built from this repo; `build_kit.sh` builds, `preflight.sh` proves |

## Measured baseline (fp32 KV, chunk 1024, ctx 36864)

```
ctx0:  decode 21.6 tok/s   peak VRAM 7.26 GiB
```

That is the number the int4 KV work must not lose, and the optimization campaign must beat.

## Thermite state (Mac, `http://127.0.0.1:8800/ui`)

| Campaign | State | Pins | Why |
| --- | --- | --- | --- |
| `qwen36-strata-maximization` (v1) | archived | — | SGLang dead end |
| `qwen36-strata-maximization-v2` | archived? no — paused | — | superseded |
| `qwen36-strata-maximization-v3` | paused | project `ba797d2`, kit `b478ed5` | kit moved forward live |
| `qwen36-strata-maximization-v4` | paused | project `d9e4290`, kit `ca7b672` | fp32 reference |
| `qwen36-int4-kv` | paused | project `9295084`, kit `dd25c45` | int4 KV patch, now done outside Thermite |
| `qwen36-strata-optimization` | **run 1 running** | project `94503e4`, kit `dd25c45` | the live optimization hill climb |

`qwen36-strata-optimization-1` was assigned 2026-11-15T20:08Z with `OPTIMIZATION-CONTRACT.json`
(contract sha `cbce52e4…`). Cells are `ctx0` and `ctx32k` only: fp32 KV cannot start 64K.
`lanes.keep_working` is true, 2 lanes, `workspace_mib 32768`, `dev_run_rss_mib 12288`,
`trial_minutes 1440`, wall 8760 h.

**Its blocker (2026-11-15T20:18Z): the judge's idle-GPU gate.** The seed built in 507 s, then the
baseline failed twice with `target not ready for timing: 818 MiB in use before timing`. The
harness refuses to time unless the GPU shows no compute processes, <5% utilisation and
**<600 MiB used**; this WSL rig idles at 818-927 MiB. Every earlier baseline (927, 895, 895 MiB)
died the same way, which is why no campaign has ever had a baseline. The gate is hardcoded in the
harness image (`dist/harness/targets/cuda.js`, `maxIdleMemoryMiB: 600`), not a contract field, and
the API has no "skip baseline". A hill climb's planner will not start a round until the baseline
measures, so freeing ~220 MiB of GPU memory (stale `serve.server`/`strata`, or Windows apps) is what
unblocks it; the judge retries on its own.

## What is next

1. Free the GPU's idle memory and let the baseline measure; then the hill climb starts by itself.
2. If it cannot go below 600 MiB, the harness image's threshold has to be raised (a patched image),
   or the loop must run unmeasured (judge off), which advances no champion.

## Knowledge that took a day to learn (do not rediscover)

- **The engine is Strata**, not SGLang. `src/qwen35` is the Qwen3.6 path; `strata` dispatches to it from the
  GGUF's `qwen35moe` architecture string.
- **Only Q5_K / Q6_K / Q8_0 GGUF quants run.** Q4_K and Q3_K are refused: their expert `down_proj` type is not in
  `STRATA_D_FMTS` (`src/kernels/cuda/iq_kernels.cu`). Q5_K_S = 24.6 GB for a 26 GB box.
- **KV cache is fp32, hardcoded.** 45,056 B/token (11 attention layers × 2 × 2 KV heads × 256 dim × 4 B). No
  `--kv` flag exists in this path; that is what the patch adds.
- **Lane workspace defaults to 2 GiB**, which kills every CUDA build (`exit SIGKILL (killed: disk)`). Set
  `limits.workspace_mib: 32768` in the contract and `dev_run_rss_mib: 12288` via the `lane_limits` command.
- **The judge's build sandbox has python3 and network but no curl, wget or pip.** `build_kit.sh` fetches CMake with
  python3 for that reason, and only when system CMake < 3.24.
- **The kit's benchmark must use `/v1/chat/completions`.** Strata has no `/v1/completions`; the old client 404'd.
  Its SSE pieces are text events, so tokens are counted by tokenizing, not by counting chunks.
- **Thermite has no campaign delete and no way to re-pin a project commit.** Contracts pin project and kit; the kit
  can be moved forward live with the `kit_commit` command, the project cannot. A project change means a new
  campaign.
- **`reset_workers` discards the lane workspace**, so a build fix made inside a lane is lost. Raise limits before
  resetting, never after.
- **Context must be `auto` in the kit** (`MAX_CONTEXT=auto`), or a 64K/128K cell is impossible before the KV patch.
- **Engine log for the server is `strata-qwen36.log`** in the project root, not the server's stdout: that is where
  `MTP block loaded` and `prompt chunk N` are printed.
- **The judge's timing gate is 600 MiB of idle VRAM, 5% utilisation and no compute processes.** This WSL rig idles
  at 818-927 MiB, so every baseline fails with `target not ready for timing`. The number is hardcoded in the
  harness image (`maxIdleMemoryMiB: 600`), not a setting. No API skips a hill climb's baseline, and the planner
  does not start a round without one.

## Open questions

- Whether int4 KV's numerics hold at 128K (unknown until the patch lands).
- Whether 64K/128K cells fit and finish inside 15 minutes on this card; the 32K prefill is CPU-bound at ~46% of six
  cores with `chunk 512`, better at 1024.
- MTP is confirmed present (`blk.40.nextn.*`, `nextn_predict_layers=1`, `MTP block loaded`), and drafting is on.
