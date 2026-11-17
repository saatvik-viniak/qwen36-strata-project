#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
/opt/strata/venv/bin/python - <<'EOF'
import struct
p = "/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf"
f = open(p, "rb")
def rd(fmt):
    n = struct.calcsize(fmt); return struct.unpack(fmt, f.read(n))[0]
def skip(n):
    f.seek(n, 1)
def rd_str():
    n = rd("<Q"); return f.read(n).decode("utf-8", "replace")
assert f.read(4) == b"GGUF"
ver = rd("<I"); ntens = rd("<q"); nkv = rd("<q")
print(f"gguf v{ver}: {ntens} tensors, {nkv} kv pairs  (enum: 6=f32 7=bool 8=str 9=array 10=u64 11=i64 12=f64)")
SZ = {0:1, 1:1, 2:2, 3:2, 4:4, 5:4, 6:4, 7:1, 10:8, 11:8, 12:8}
FMT = {0:"<B", 1:"<b", 2:"<H", 3:"<h", 4:"<I", 5:"<i", 6:"<f", 7:"<b", 10:"<Q", 11:"<q", 12:"<d"}
for i in range(nkv):
    k = rd_str(); t = rd("<i")
    if t == 9:                      # array: elem type i32, count u64, items
        et = rd("<i"); n = rd("<Q")
        if et == 8:
            for _ in range(n):
                skip(rd("<Q"))
        elif et in SZ:
            skip(n * SZ[et])
        print(f"  [{k}] = array<{et}> x {n}")
        continue
    if t == 8:
        v = rd_str()
    else:
        v = rd(FMT[t])
    print(f"{k} = {v}")
EOF
