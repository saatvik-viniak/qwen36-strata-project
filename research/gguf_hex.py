#!/usr/bin/env python3
import struct
GGUF = "/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf"
f = open(GGUF, 'rb')
b = f.read(256)
print("HEX:", b[:96].hex())
# try interpretations
magic, ver, t1, t2 = struct.unpack('<4sQQQ', b[:4+8+8+8])
print("v3-style: magic", magic, "ver", ver, "tensors", t1, "kvs", t2)
off = 4 + 8 + 8 + 8
# first KV: u64 keylen + key
klen = struct.unpack('<Q', b[off:off+8])[0]
print("u64 keylen at", off, "=", klen)
if 0 < klen < 128:
    key = b[off+8:off+8+klen]
    print("key:", key)
    p = off + 8 + klen
    vt = struct.unpack('<I', b[p:p+4])[0]
    print("vtype:", vt)
    p += 4
    if vt == 5:
        vlen = struct.unpack('<Q', b[p:p+8])[0]
        print("strlen:", vlen, "value:", b[p+8:p+8+vlen])
