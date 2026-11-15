# Creating a campaign for this project

Two walls cost the first run an hour and 13.7M tokens. This is the checklist that avoids them.

## The two walls

| Wall | What happened | What prevents it |
| --- | --- | --- |
| Lane workspace is 2048 MiB by default | Every lane `build_kit.sh` died in ~1 s with `exit SIGKILL (killed: disk)`; a CUDA build of this engine needs far more | `limits.workspace_mib: 32768` in the campaign draft, and 12 GiB of development memory |
| The host's cmake is 3.22, the tree wanted 3.24 | The judge could not configure the seed at all | `build_kit.sh` fetches a private CMake 3.31 into `.toolchain/` when the host's is under 3.24 |

## Draft fields that matter

```json
{
  "project": { "commit": "<a commit of this repo>" },
  "kit": { "repo": "qwen36-strata", "commit": "<kit commit>" },
  "cells": ["ctx0", "ctx32k", "ctx64k"],
  "lanes": 2,
  "queue_target": 2,
  "limits": { "workspace_mib": 32768, "trial_minutes": 180 },
  "score": { "name": "decode_tps", "direction": "max", "min_effect": 0.02 }
}
```

`limits.workspace_mib` is the one that matters: 32768 MiB is the lane's whole trial directory, build
trees included. `trial_minutes: 180` gives a lane time for one real compile plus its model turns.

`dev_run_rss_mib` is **not** in the campaign form; it is a contract lane limit only. Set it right
after the run is assigned:

```sh
curl -sS -X POST http://127.0.0.1:8800/v1/commands \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"rig":"windows-rig","kind":"lane_limits","payload":{
        "run":"<run>",
        "limits":{"workspace_mib":32768,"dev_run_rss_mib":12288},
        "reason":"A CUDA build needs more than the default 2 GiB workspace and 4 GiB development memory."}}'
```

## Before a campaign starts

Run these on the rig, in this order. Each one catches a failure that otherwise shows up only
inside a trial:

```sh
./setup_rig.sh                 # toolchain, /opt/strata/venv, private cmake if needed
./download_model.sh Q5_K_S /models/qwen36-heretic
out/strata --families | grep -qw qwen35moe      # the family path is compiled in
./build_kit.sh                                  # the same build the judge runs
export MODEL_GGUF=/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf
export MAX_CONTEXT=32768 PORT=30000
./serve.sh &
curl -s http://127.0.0.1:30000/health          # "loaded": true
curl -s http://127.0.0.1:30000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.6-35b-a3b","messages":[{"role":"user","content":"hi"}],"max_tokens":8}'
```

A run costs hours; these cost minutes.

## Reading a stuck run

| Symptom | Where | Meaning |
| --- | --- | --- |
| `killed: disk` on every command, even `tail` | lane terminal | The trial directory is already over its workspace; raise the limit and reset the lanes |
| `killed: SIGKILL` on a build only | lane terminal | Memory, not disk: lower `JOBS`, or raise `dev_run_rss_mib` |
| `Configuring incomplete` in the judge's reason | Experiments tab | The build step, before any measurement; read the first `CMake Error` |
| 0 attempts after an hour | run page | Lanes are working, the judge has had nothing to measure; look at the lane terminal, not the champion |

`reset_workers` (dashboard: Restart the lanes) sends every lane back to the champion **and discards
its workspace**, so any build fix a lane made in its tree is lost. Raise limits *before* resetting.
