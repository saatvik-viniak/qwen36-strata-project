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
magic = f.read(4); assert magic == b"GGUF", magic
ver = rd("<I"); ntens = rd("<Q"); nkv = rd("<Q")
print(f"gguf v{ver}: {ntens} tensors, {nkv} kv pairs")
SZ = {0:1, 1:1, 2:2, 3:2, 4:4, 5:4, 6:8, 7:8, 8:4, 9:8, 12:1}
FMT = {0:"<B", 1:"<b", 2:"<H", 3:"<h", 4:"<I", 5:"<i", 6:"<Q", 7:"<q", 8:"<f", 9:"<d", 12:"<B"}
def rd_str():
    n = rd("<Q"); return f.read(n).decode("utf-8", "replace")
want = ("block", "head", "dim", "expert", "kv", "rope", "ctx", "emb",
        "vocab", "mtp", "arch", "attention", "ff", "feed", "general")
out = []
for i in range(nkv):
    try:
        k = rd_str(); t = rd("<I")
        if t == 11:                     # array
            et = rd("<I"); n = rd("<Q")
            if et == 10:                # array of strings
                for _ in range(n):
                    ln = rd("<Q"); skip(ln)
            elif et in SZ:
                skip(n * SZ[et])
            else:
                skip(n * 8)             # best-effort
            continue
        if t == 10:
            v = rd_str()
        elif t in FMT:
            v = rd(FMT[t])
        else:
            v = f"(type {t}, skipped)"
        lk = k.lower()
        if any(w in lk for w in want) and t != 10:
            out.append(f"{k} = {v}")
    except Exception as e:
        print(f"kv[{i}]: error {e!r}"); break
for line in out:
    print(line)
EOF
