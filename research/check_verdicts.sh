#!/bin/bash
# check_verdicts.sh — summarize trial results vs the baseline medians (A/B deltas).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
declare -A BASE=( [empty]=21.89 [ctx32k]=19.52 [ctx128k]=11.73 )
declare -A TGT=(  [empty]=43.85 [ctx32k]=37.87 [ctx128k]=23.60 )
for T in nommq ct5 mtp3; do
  echo "== $T =="
  for C in empty ctx32k ctx128k; do
    F="$WS/research/trials/$T/$C.json"
    if [ -f "$F" ]; then
      TPS=$(python3 -c "import json;print(f\"{json.load(open('$F'))['decode_tps']:.2f}\")" 2>/dev/null)
      PK=$(python3 -c "import json;print(f\"{json.load(open('$F'))['peak_gib']:.2f}\")" 2>/dev/null)
      B=${BASE[$C]}
      D=$(python3 -c "print(f'{($TPS/$B-1)*100:+.1f}%')" 2>/dev/null)
      X2=$(python3 -c "print(f'{$TPS/${TGT[$C]}:.2f}x')" 2>/dev/null)
      echo "  $C: $TPS tok/s (baseline $B -> $D; $X2 of 2x target) peak $PK GiB"
    else
      echo "  $C: (no result yet)"
    fi
  done
  V="$WS/research/trials/$T/vram.log"
  [ -f "$V" ] && echo "  VRAM peak seen: $(sort -t' ' -k2 -n "$V" | tail -1)"
done
echo ""
echo "== runner state =="
cat "$WS/research/trial_runner.done" 2>/dev/null || echo "(not done)"
ps aux --width 200 | grep -E 'trial_runner|bench.py' | grep -v grep || echo "(no runner processes)"
