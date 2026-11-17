#!/usr/bin/env python3
"""append_ledger_prom.py — append the two promotion-decision entries to the trial
ledger (research/hillclimb/ledger.jsonl). Python applier (not the edit tool): the
earlier edit-tool anchor failed unexplained; this appends in binary mode after
asserting the exact current tail, so it cannot silently corrupt the file.

Anchors: the file must end with b're-measure"}\n' (the q5k-chain-v4 entry's verdict
tail, verified by od -c), must be 21 lines, and must not already contain the new
entries (idempotent). Each new line is json.dumps'd and validated by json.loads.
"""
import json

PATH = "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/hillclimb/ledger.jsonl"

E1 = {
    "ts": "2026-11-17T09:59:00Z",
    "run": "promotion-compose-clean",
    "config": "promotion_pass.sh v2 (the trigger verified the v6 marker AND the A/B results on disk AND the compose binary != base; MODEL_PATH exported; serve_262k_q5k.sh, STRATA_KQ256=1; wait health; settle 900 s; empty/ctx32k/ctx128k, NO watchdog; failures counted; the champion restored)",
    "binary": "out/strata_q5k_cand md5 8833c30b, 85,113,360 B (the compose: q5k + uint4 + the pinerr diagnostic + the kq engagement line; the cmp gate 10/10 bit-identical vs the champion)",
    "cells": {
        "empty": "22.53 tok/s (anchor 21.89: +2.9%)",
        "ctx32k": "21.76 tok/s (anchor 19.52: +11.5%; prefill 275.1 vs 249.8)",
        "ctx128k": "17.52 tok/s (anchor 11.73: +49.4%; consistent with the uint4 verdict's 17.77 watchdogged and the predicted ~17.7)",
    },
    "source": "research/promotion/{empty,ctx32k,ctx128k}.json + research/promotion.log; promotion.done = bench_complete (truthful)",
    "verdict": "the compose-clean triple recorded; the deltas vs the cross-day anchors CONFLICTED with the same-day A/B at ctx32k (+11.5% vs +0.59%) - the window effect was not separable from the anchors alone -> the base leg (the same protocol on byte_loop) was demanded and run",
}

E2 = {
    "ts": "2026-11-17T10:52:06Z",
    "run": "promotion-base-clean",
    "config": "promotion_base_pass.sh (the supplementary agent's window-conflict demand, adopted): the SAME protocol with the binary swapped - it reused the champion server that v2's restore loaded (health 10:05:05Z; both passes got the identical 900-s-post-health settle), cmp-verified out/strata == strata_q5k_base, exported MODEL_PATH, counted failures, ran empty/ctx32k/ctx128k in the same order, NO watchdog",
    "binary": "out/strata == out/strata_q5k_base md5 74c5f1f4 (the byte-loop champion)",
    "cells": {
        "empty": "21.57 tok/s",
        "ctx32k": "19.77 tok/s",
        "ctx128k": "11.97 tok/s",
    },
    "anchor_check": "the base-clean reads within ±2% of the clean anchors (21.89/19.52/11.73): -1.5% / +1.3% / +2.0% - the anchors were valid comparators; the historical ledger stays valid",
    "source": "research/promotion/base_{empty,ctx32k,ctx128k}.json + research/promotion_base.log; promotion_base.done = bench_complete (truthful)",
    "verdict": "PROMOTE - the compose/base same-day same-protocol deltas: empty +4.4% (22.53 vs 21.57), ctx32k +10.0% (21.76 vs 19.77), ctx128k +46.4% (17.52 vs 11.97); the median win +10.0% >= the 2% bar, NO cell regresses, the output is bit-identical (the cmp gate 10/10), the kq engagement line is proven live in the serving log. THE COMPOSE BINARY (md5 8833c30b, q5k+uint4+pinerr+kqlog, STRATA_KQ256=1) IS THE NEW CHAMPION CONFIG; future chains' restore semantics = cp strata_q5k_cand -> out/strata + serve_262k_q5k.sh. The 2.00x targets stand at empty 22.53/43.85 (51%), ctx32k 21.76/37.87 (57%), ctx128k 17.52/23.60 (74%); the queue: §9.0 profiling on the new champion + the host-bandwidth capture -> S12-C (the worker count) -> S12-B (the TLB microbench) -> the THP+STRATA_POOLMS build",
}

data = open(PATH, "rb").read()
n_before = data.count(b"\n")
tail = data.rstrip(b"\n")
assert tail.endswith(b're-measure"}'), f"unexpected tail bytes: {data[-20:]!r}"
assert b"promotion-compose-clean" not in data and b"promotion-base-clean" not in data, "entries already present"
assert n_before == 21, f"expected 21 lines, got {n_before}"

line1 = json.dumps(E1, ensure_ascii=False)
line2 = json.dumps(E2, ensure_ascii=False)
json.loads(line1); json.loads(line2)  # validate before touching the file
with open(PATH, "ab") as f:
    f.write((line1 + "\n" + line2 + "\n").encode("utf-8"))

new = open(PATH, "rb").read()
n_after = new.count(b"\n")
for ln in (line1, line2):
    json.loads(ln)  # re-validate from the actual bytes
assert new.count(line1.encode()) == 1 and new.count(line2.encode()) == 1
print(f"append ok: {n_before} -> {n_after} lines")
print(f"last two runs: promotion-compose-clean (09:59:00Z), promotion-base-clean (10:52:06Z)")
