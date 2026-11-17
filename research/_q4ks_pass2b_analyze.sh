#!/bin/bash
# _q4ks_pass2b_analyze.sh — the pass2b drift-bound harvest, printed as a table.
# Reads research/q4ks_baseline_pass2/*.json (pass 2b) and research/q4ks_baseline/*.json
# (pass 1) and prints per-cell: pass1, pass2b, the drift %, plus the prefill drift and
# the row-3 comparator check (empty 22.53 / ctx32k 21.76 / ctx128k 17.52, 09:27-09:58Z).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
PY=/opt/strata/venv/bin/python
P2=$WS/research/q4ks_baseline_pass2
P1=$WS/research/q4ks_baseline
"$PY" - "$P1" "$P2" <<'EOF'
import json, os, sys
p1, p2 = sys.argv[1], sys.argv[2]
ROW3 = {"empty": 22.53, "ctx32k": 21.76, "ctx128k": 17.52}
cells = ["empty", "ctx32k", "ctx128k"]
print("cell      pass1    pass2b   drift%   prefill1 -> prefill2 (drift%)   vs row3 pass2b%")
for c in cells:
    a = json.load(open(os.path.join(p1, c + ".json")))
    b = json.load(open(os.path.join(p2, c + ".json")))
    d1, d2 = a["decode_tps"], b["decode_tps"]
    drift = (d2 / d1 - 1) * 100
    pf1, pf2 = a.get("prefill_tps"), b.get("prefill_tps")
    pfd = "" if pf1 is None or pf2 is None or pf1 < 5 else f"{pf1:.1f} -> {pf2:.1f} ({(pf2/pf1-1)*100:+.1f}%)"
    r3 = (d2 / ROW3[c] - 1) * 100
    o1 = a["requests"][0]["output_tokens"] if "requests" in a else "?"
    o2 = b["requests"][0]["output_tokens"] if "requests" in b else "?"
    print(f"{c:8} {d1:7.2f}  {d2:8.2f}  {drift:+6.1f}%  {pfd:38}  {r3:+6.1f}%  out {o1}->{o2}")
EOF
