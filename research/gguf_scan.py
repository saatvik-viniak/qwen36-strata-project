#!/usr/bin/env python3
"""Scan GGUF KVs with value skipping. Empirical dialect: STRING=8 (u64 len).
Unknown vtypes print raw bytes and stop, so the enum can be completed."""
import struct, sys
GGUF = "/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf"
f = open(GGUF, 'rb')
def rd(fmt):
    sz = struct.calcsize('<' + fmt)
    return struct.unpack('<' + fmt, f.read(sz))[0]
assert f.read(4) == b'GGUF'
ver, n_tensors, n_kv = rd('I'), rd('Q'), rd('Q')
print(f"ver {ver} tensors {n_tensors} kvs {n_kv}")

def skip_string():
    n = rd('Q'); f.read(n)

def skip_value(vt):
    if vt == 8: skip_string()
    elif vt in (0, 9): f.read(1)
    elif vt in (1,): f.read(1)
    elif vt in (2, 3): f.read(2)
    elif vt in (4, 5, 6): f.read(4)
    elif vt in (7,): f.read(8)
    elif vt in (10, 11): f.read(8)
    elif vt == 12:  # array guess: u32 elemtype, u64 count, elems
        at = rd('I'); n = rd('Q')
        if at == 8:
            # string array: skip each
            for _ in range(n):
                ln = rd('Q'); f.read(ln)
        else:
            esz = {0:1,1:1,2:2,3:2,4:4,5:4,6:4,7:8,8:None,9:1,10:8,11:8}.get(at)
            if esz is None:
                raise ValueError(f"array of unknown elemtype {at}")
            f.read(esz * n)
    else:
        raise ValueError(f"unknown vtype {vt}")

for i in range(n_kv):
    klen = rd('Q')
    key = f.read(klen).decode()
    vt = rd('I')
    raw = f.read(24)
    f.seek(f.tell() - 24)
    print(f"[{i:02d}] vtype={vt:<3d} key={key!r} raw={raw.hex()}")
    try:
        skip_value(vt)
    except Exception as e:
        print(f"  !! stop at KV {i}: {e}")
        break
print("done; file pos", f.tell())
