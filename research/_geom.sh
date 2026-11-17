#!/bin/bash
# temp helper: geometry sources - the engine log's cache lines + the GGUF header parse
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== the engine log's geometry/cache lines =="
grep -i "kv\|cache\|geometry\|GiB\|layers" /home/dmin/qwen36-strata-project/strata-qwen36.log 2>/dev/null | grep -v "q5k multi-token" | tail -12
echo ""
echo "== the GGUF header parse (my minimal parser) =="
/opt/strata/venv/bin/python - <<'EOF'
import struct, sys
p = "/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf"
f = open(p, "rb")
def rd(fmt):
    n = struct.calcsize(fmt); return struct.unpack(fmt, f.read(n))[0]
assert f.read(4) == b"GGGF"
ver, cnt_tensors = rd("<Q"), rd("<Q")
n_kv = rd("<Q")
def rd_str():
    n = rd("<Q"); return f.read(n).decode("utf-8", "replace")
def rd_val(t):
    if t == 0: return rd("<u1") if False else rd("<B")   # u1..u8 map below
    raise ValueError(t)
T = {0:("<B",1),1:("<b",1),2:("<H",2),3:("<h",2),4:("<I",4),5:("<i",4),6:("<Q",8),7:("<q",8),8:(None,0),9:("<f",4),10:("<d",8)}
want = ("block","head","dim","experts","kv","rope","ctx","emb","vocab","mtp","arch","general")
for _ in range(n_kv):
    k = rd_str()
    t = rd("<I")
    if t in (8,):           # array: skip (type + count + items)
        at = rd("<I"); ac = rd("<Q")
        fmt, sz = T.get(at, (None, 0))
        if fmt is None:     # array of strings
            for _ in range(ac): rd_str()
        elif at == 8: pass
        else:
            f.seek(ac * sz, 1)
        continue
    if t == 9 or t == 10:   # f32 / f64
        fmt, sz = T[t]; v = rd(fmt)
    elif t in (0,1,2,3,4,5,6,7):
        fmt, sz = T[t]; v = rd(fmt)
    elif t == 11:           # string
        v = rd_str()
    elif t == 12:           # bool
        v = bool(rd("<B"))
    else:
        v = f"(type {t})"
    if any(w in k.lower() for w in want):
        print(f"{k} = {v}")
EOF
