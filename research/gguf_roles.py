#!/usr/bin/env python3
"""Dump every unique tensor role: name pattern, dims, qtype — for ceiling byte math."""
import re, struct, sys, collections
GGUF = "/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf"
TYPE_SIZE = {0:4, 1:2, 2:0.5625, 3:0.625, 6:0.6875, 7:0.75, 8:1.0, 10:0.3203, 11:0.4453, 12:0.4922, 13:0.5469, 14:0.5527, 15:0.6, 16:0.6875, 17:0.7168, 18:0.8125, 19:2.0625/8, 20:2.0625/8*1.0, 22:0.4453, 23:0.1934, 24:0.5156, 25:0.4453, 26:0.3203, 27:0.5156, 28:1.0, 29:2.0, 30:4.0, 31:8.0, 34:2.0}
f = open(GGUF, 'rb')
def rd(fmt):
    sz = struct.calcsize('<' + fmt)
    return struct.unpack('<' + fmt, f.read(sz))[0]
assert f.read(4) == b'GGUF'
ver, n_tensors, n_kv = rd('I'), rd('Q'), rd('Q')
def rd_string():
    n = rd('Q')
    return f.read(n).decode('utf-8', 'replace')
for _ in range(n_kv):
    rd_string(); t = rd('I')
    # skip value
    if t == 8: rd_string()
    elif t == 9:
        at = rd('I'); n = rd('Q')
        if at == 8:
            for _ in range(n): rd_string()
        else:
            esz = {0:1,1:1,2:2,3:2,4:4,5:4,6:4,7:8,10:8,11:8}[at]
            f.read(esz * n)
    elif t in (4,5): f.read(4)
    elif t in (10,11): f.read(8)
    elif t == 6: f.read(4)
    elif t == 7: f.read(8)
    elif t in (0,1): f.read(1)
    elif t in (2,3): f.read(2)

pats = collections.defaultdict(set)
qt_by_pat = {}
for i in range(n_tensors):
    name = rd_string()
    nd = rd('I')
    dims = [rd('Q') for _ in range(nd)]
    qt = rd('I')
    off = rd('Q')
    pat = re.sub(r'\b\d+\b', 'N', name)
    pats[pat].add(tuple(dims))
    qt_by_pat[pat] = qt
for pat in sorted(pats):
    dims = sorted(pats[pat], key=lambda d: -__import__('math').prod(d))
    print(f"q={qt_by_pat[pat]:<3d} {pat:48s} dims={dims[:2]}")
