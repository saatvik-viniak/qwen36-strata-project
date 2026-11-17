#!/usr/bin/env python3
import hashlib
A = "/home/dmin/qwen36-strata-project/src/kernels/cpu/pool.cpp"
B = "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/src/kernels/cpu/pool.cpp"
for p in (A, B):
    raw = open(p, "rb").read()
    norm = raw.replace(b"\r\n", b"\n")
    print(p.split("/src/")[0][-20:] if "/mnt" not in p else "C: checkout",
          "raw md5", hashlib.md5(raw).hexdigest()[:8],
          "norm md5", hashlib.md5(norm).hexdigest()[:8],
          "CRLF" if b"\r\n" in raw else "LF-only", len(raw), "bytes")
ra, rb = open(A, "rb").read(), open(B, "rb").read()
print("identical after CRLF->LF normalization:", ra == rb.replace(b"\r\n", b"\n"))
