#!/bin/bash
# _readpoolms.sh — the supplementary agent's refined Lever-A reading (read-only):
# the pre-registered protocol (SUGGESTIONS.MD S13) applied to the capture slice.
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
E=$WS/research/poolms/engine.log
J=$WS/research/poolms/empty.json
date -u +%H:%M:%SZ
echo "== the slice's shape =="
wc -l < "$E"
echo "== the q5k + load block =="
grep -m1 "q5k" "$E"
grep -m2 "cudaHostAlloc\|hybrid experts" "$E"
echo ""
echo "== the session lines (the round boundaries + the accept rates) =="
grep -n "session 0" "$E"
S1=$(grep -n "session 0" "$E" | head -1 | cut -d: -f1)
S2=$(grep -n "session 0" "$E" | tail -1 | cut -d: -f1)
echo "(S1=$S1 S2=$S2)"
echo ""
echo "== poolms/empty.json's decode_ms + text match vs the promotion anchor =="
grep -o '"decode_ms": [0-9.]*' "$J" | tail -1
grep -o '"output_tokens": 512' "$J" | head -1
T_NEW=$(python3 -c "import json;print(json.load(open('$J'.replace('C:','/mnt/c')))['requests'][0]['text'][:80])" 2>/dev/null || echo "(py fail)")
P=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/promotion/empty.json
T_OLD=$(python3 -c "import json;print(json.load(open('$P'))['requests'][0]['text'][:80])" 2>/dev/null || echo "(py fail)")
echo "capture text: $T_NEW"
echo "anchor  text: $T_OLD"
[ "$T_NEW" = "$T_OLD" ] && echo "TEXT IDENTICAL (greedy, same routing -> tokens/step comparable)" || echo "TEXT DIFFERS"
echo ""
echo "== THE MEASURED ROUND ONLY (between session 1 and 2) =="
sed -n "$((S1 + 1)),$((S2 - 1))p" "$E" | grep "strata pool-ms" > /tmp/pm_meas.txt
wc -l < /tmp/pm_meas.txt
awk '{ if (match($0, /pool-ms: ([0-9.]+) ms \(gu ([0-9.]+) \/ q ([0-9.]+) \/ down ([0-9.]+)\), ([0-9]+) experts, ([0-9.]+) MB, ([0-9.]+) GB/, a)) {
  n++; ms+=a[1]; gu+=a[2]; q+=a[3]; down+=a[4]; ex+=a[5]; mb+=a[6]; gb+=a[7];
  if (a[1]>mx) mx=a[1]; if (mn==0 || a[1]<mn) mn=a[1] } }
 END { if (!n) { print "(no lines)"; exit }
  printf "lines %d; SUM %.0f ms; mean %.2f ms (min %.2f max %.2f)\n", n, ms, ms/n, mn, mx;
  printf "phases: gu %.0f (%.1f%%) q %.0f (%.1f%%) down %.0f (%.1f%%)\n", gu, gu*100/ms, q, q*100/ms, down, down*100/ms;
  printf "experts/call mean %.1f -> distinct/layer %.1f (the 8-24 bracket)\n", ex/n, ex/n;
  printf "MB/call mean %.1f; volume/step x41 = %.0f MB (the 660-1980 bracket)\n", mb/n, mb/n*41;
  printf "per-call GB/s mean %.2f; aggregate %.2f (the S12-B ceiling 28)\n", gb/n, mb/ms;
  printf "pool share vs decode_ms 26853: %.1f%%\n", ms/26853*100 }' /tmp/pm_meas.txt
echo ""
echo "== THE PRE-MEASURED REGION (load warmup + the bench's warmup round) =="
head -c 0 /dev/null; sed -n "1,$S1 p" "$E" | grep "strata pool-ms" > /tmp/pm_pre.txt
awk '{ if (match($0, /pool-ms: ([0-9.]+) ms/, a)) { n++; ms+=a[1]; if (mn==0||a[1]<mn) mn=a[1]; s+=$0 }
  if (match($0, /pool-ms: ([0-9.]+) ms \(gu ([0-9.]+)/, b)) gu2+=b[2] }
 END { if (!n) { print "(no lines)"; exit }
  printf "lines %d; SUM %.0f ms; mean %.2f ms (min %.2f) — vs the measured mean above\n", n, ms, ms/n, mn }' /tmp/pm_pre.txt
