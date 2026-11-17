#!/bin/bash
# analyze_poolms.sh — Lever A's capture analysis (run after poolms.done):
#   the pool's share of the step + the per-call effective GB/s + the volume
#   bracket check vs the supplementary agent's 660 MB-1.98 GB/step estimate
#   (8-24 distinct experts/layer x 41 layers x 2.01 MB) and vs the S12-B
#   28 GB/s warmed-stream ceiling. The bench runs warmup+measured, so the
#   measured round's pool-ms total ~ SUM/2.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
E=$WS/research/poolms/engine.log
J=$WS/research/poolms/empty.json
[ -s "$E" ] || { echo "no engine.log"; exit 1; }
DTPS=$(grep -o '"decode_tps": [0-9.]*' "$J" 2>/dev/null | head -1 | grep -o '[0-9.]*$')
echo "decode_tps: $DTPS -> the measured round ~ $(awk -v t="$DTPS" 'BEGIN{printf "%.1f s", 512/t*1000}') ms"
echo "== q5k engagement in the slice =="
grep -m1 "q5k" "$E" || echo "(no q5k line)"
echo "== the pool-ms totals =="
grep "strata pool-ms" "$E" | sed -E 's/.*pool-ms: ([0-9.]+) ms \(gu ([0-9.]+) \/ q ([0-9.]+) \/ down ([0-9.]+)\), ([0-9]+) experts, ([0-9.]+) MB, ([0-9.]+) GB.*/\1 \2 \3 \4 \5 \6 \7/' \
| awk -v dtp="$DTPS" '
  { n++; ms+=$1; gu+=$2; q+=$3; down+=$4; exps+=$5; mb+=$6; t7+=$7
    if ($1>maxms || n==1) maxms=$1
    if (n==1 || $1<minms) minms=$1 }
  END {
    if (n==0) { print "no pool-ms lines"; exit }
    printf("calls %d; SUM %.0f ms (measured round ~%.0f ms); mean/call %.1f ms (min %.1f max %.1f)\n", n, ms, ms/2, ms/n, minms, maxms)
    printf("phase totals: gu %.0f (%.1f%%) / q %.0f (%.1f%%) / down %.0f (%.1f%%)\n", gu, gu*100/ms, q, q*100/ms, down, down*100/ms)
    printf("experts/call mean %.1f (x41 layers -> %.1f distinct/layer vs the 8-24 bracket)\n", exps/n, exps/n/41)
    printf("volume/call mean %.1f MB (total %.0f MB) vs the 660 MB-1.98 GB bracket\n", mb/n, mb)
    printf("per-call GB/s: mean %.2f (the S12-B warmed ceiling 28)\n", t7/n)
    printf("aggregate GB/s = total MB / SUM ms = %.2f\n", ms>0 ? mb/ms : 0)
    if (dtp != "") {
      dec = 512/dtp*1000
      printf("pool share: SUM/2 %.0f ms of the ~%.0f ms measured decode = %.1f%%\n", ms/2, dec, dec>0 ? ms/2/dec*100 : 0)
    }
  }'
echo "== the first 3 + last 3 lines =="
grep "strata pool-ms" "$E" | head -3
grep "strata pool-ms" "$E" | tail -3
