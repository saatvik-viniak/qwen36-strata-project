#!/bin/bash
echo "== build/serve processes =="
ps aux --width 250 | grep -E "build_kit|ninja|nvcc|cmake|cand_q5k|cand_runner|bench.py|serve.server|out/strata" | grep -v grep
echo "== out listing =="
ls -la --time-style=+%H:%M /home/dmin/qwen36-strata-project/out/ 2>/dev/null | head -20
echo "== cand_q5k.log v4 tail =="
tail -8 /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/cand_q5k.log 2>/dev/null
