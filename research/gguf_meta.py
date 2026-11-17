#!/usr/bin/env python3
"""Parse the heretic GGUF header fully. Empirical dialect (this writer):
   4=u32 5=i32 6=f32 8=STRING(u64 len) 9=ARRAY(u32 elemtype, u64 count, elems)
   tensor entries: u64 name_len, name, u32 nd, u64 dims[nd], u32 qtype, u64 offset
"""
import json, struct, sys, collections
GGUF = "/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf"
TYPE_SIZE = {0:1, 1:1, 2:2, 3:2, 4:4, 5:4, 6:4, 7:8, 10:8, 11:8, 12:8}
QTYPE_BITS = {20:4.5, 22:2.0625, 26:4.5, 28:3.5625, 30:3.0625, 31:3.25, 32:4.5, 33:3.5, 34:4.5, 35:4.5, 36:4.25, 37:4.5, 38:4.5, 39:3.5, 40:4.5, 41:3.5, 42:3.5, 43:3.0625, 44:4.5, 45:3.0625, 46:2.0625}
QNAME = {20:'Q4_K', 22:'IQ2_XS', 26:'Q4_K_XL?', 28:'Q3_K', 30:'Q3_K_S?', 31:'Q3_K_M?', 32:'Q4_K_M?', 33:'Q3_K_L?', 34:'Q4_K_XL?', 35:'Q4_K?', 36:'Q4_K_XL2?', 37:'Q5_K?', 38:'Q5_K_M?', 39:'Q3_K_T?', 40:'Q5_K_S?', 41:'Q5_K_M2?', 42:'Q5_K_M3?', 43:'Q3_K_XL?', 44:'Q6_K?', 45:'Q3_K_XL2?', 46:'IQ2_XXS?'}

f = open(GGUF, 'rb')
def rd(fmt):
    sz = struct.calcsize('<' + fmt)
    return struct.unpack('<' + fmt, f.read(sz))[0]

assert f.read(4) == b'GGUF'
ver, n_tensors, n_kv = rd('I'), rd('Q'), rd('Q')
print(f"ver {ver} tensors {n_tensors} kvs {n_kv}", file=sys.stderr)

def rd_string():
    n = rd('Q')
    return f.read(n).decode('utf-8', 'replace')

def rd_value(t):
    if t in (4, 5): return rd('I')
    if t in (10, 11): return rd('Q') if t == 10 else rd('q')
    if t == 6: return struct.unpack('<f', f.read(4))[0]
    if t == 7: return struct.unpack('<d', f.read(8))[0]
    if t in (0, 1): return rd('B') if t == 0 else rd('b')
    if t in (2, 3): return rd('H') if t == 2 else rd('h')
    if t == 8: return rd_string()
    if t == 9:
        at = rd('I'); n = rd('Q')
        if at == 8:
            return [rd_string() for _ in range(n)]
        esz = TYPE_SIZE.get(at)
        if esz is None:
            raise ValueError(f"array elemtype {at}")
        fmtc = {1:'b', 0:'B', 3:'h', 2:'H', 5:'i', 4:'I', 6:'f', 11:'q', 10:'Q', 7:'d'}[at]
        vals = struct.unpack('<' + fmtc * n, f.read(esz * n))
        return list(vals)
    raise ValueError(f"vtype {t}")

meta = {}
for _ in range(n_kv):
    key = rd_string()
    t = rd('I')
    meta[key] = rd_value(t)

tensors = []
for i in range(n_tensors):
    name = rd_string()
    nd = rd('I')
    dims = [rd('Q') for _ in range(nd)]
    qt = rd('I')
    off = rd('Q')
    tensors.append((name, dims, qt, off))
print(f"parsed {len(tensors)} tensors", file=sys.stderr)

def numel(dims):
    n = 1
    for d in dims: n *= d
    return n

def tbytes(dims, qt):
    n = numel(dims)
    if qt in QTYPE_BITS:
        return n * QTYPE_BITS[qt] / 8
    return n * TYPE_SIZE.get(qt, 4)

roles = collections.defaultdict(float)
for name, dims, qt, off in tensors:
    b = tbytes(dims, qt)
    ln = name.lower()
    if 'expert' in ln or 'dex' in ln or 'ff_up' in ln or 'ff_down' in ln or 'ff_gate' in ln:
        roles['routed_experts'] += b
    elif 'ssm' in ln or 'gdn' in ln or 'conv' in ln:
        roles['ssm_gdn'] += b
    elif 'attn' in ln or 'qkv' in ln or 'wo_' in ln:
        roles['attention'] += b
    elif 'router' in ln:
        roles['router'] += b
    elif 'shared' in ln or 'probe' in ln:
        roles['shared_expert'] += b
    elif 'output' in ln or 'head' in ln or 'norm' in ln or 'embd' in ln:
        roles['head_emb_norm'] += b
    else:
        roles['other'] += b

keep = {}
for k, v in meta.items():
    if isinstance(v, list) and len(str(v)) > 200:
        keep[k] = f"<array len {len(v)}: {str(v[:8])}...>"
    else:
        keep[k] = v
out = {"n_tensors": len(tensors), "roles_gb": {k: round(v/1e9, 3) for k, v in roles.items()}, "meta": keep}
print(json.dumps(out, indent=1, sort_keys=True))
print("\nTOP TENSORS:")
for name, dims, qt, b in sorted(tensors, key=lambda x: -tbytes(x[1], x[2]))[:18]:
    print(f"  {name:52s} dims={dims} q={qt}({QNAME.get(qt,'')}) {tbytes(dims, qt)/2**30:.3f} GiB")
print("\nATTENTION / EXPERT per-layer examples (first 6 of each):")
seen_a = seen_e = 0
for name, dims, qt, off in tensors:
    ln = name.lower()
    if ('attn' in ln or 'qkv' in ln or 'wo_' in ln) and seen_a < 6:
        print(f"  ATTN {name} dims={dims} q={qt} {tbytes(dims, qt)/2**20:.2f} MiB"); seen_a += 1
    if 'expert' in ln and seen_e < 6:
        print(f"  EXP {name} dims={dims} q={qt} {tbytes(dims, qt)/2**20:.2f} MiB"); seen_e += 1
