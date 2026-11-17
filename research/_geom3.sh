#!/bin/bash
/opt/strata/venv/bin/python - <<'EOF'
f = open("/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf", "rb")
b = f.read(160)
import struct
print("hex:", b[:64].hex())
print("magic:", b[:4])
ver = struct.unpack("<I", b[4:8])[0]
nt = struct.unpack("<Q", b[8:16])[0]
nk = struct.unpack("<Q", b[16:24])[0]
print("ver:", ver, "tensors:", nt, "kv:", nk)
off = 24
kl = struct.unpack("<Q", b[off:off+8])[0]
key = b[off+8:off+8+kl]
print("kv[0] key_len:", kl, "key:", key)
off = off + 8 + kl
t = struct.unpack("<I", b[off:off+4])[0]
print("kv[0] type:", t)
off += 4
if t == 10:
    vl = struct.unpack("<Q", b[off:off+8])[0]
    print("kv[0] str_len:", vl, "val:", b[off+8:off+8+vl])
    off += 8 + vl
print("next bytes:", b[off:off+40])
EOF
