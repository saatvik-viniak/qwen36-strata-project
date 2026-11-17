#!/usr/bin/env python3
"""apply_uint4.py — patch the WSL clone's q36_engine.cu with the uint4 QK read.

The clone carries the int4 KV work as LOCAL UNCOMMITTED edits (its HEAD predates
it), so a git pull would conflict; this applies the same targeted edit that
dd9fee1 made in the canonical checkout. Idempotent: skips if already applied.
"""
import sys

OLD = """            const uint8_t* kp = (const uint8_t*) kcr.data + ((size_t) kvh * ctx + p) * (HD / 2);
            const float ks = __half2float(kcr.scale[(size_t) kvh * ctx + p]);
#pragma unroll 4
            for (int i = 0; i < HD; i += 2) {
                const uint8_t b = kp[i >> 1];
                a += qs[i] * (kv_q4(b, 0) * ks) + qs[i + 1] * (kv_q4(b, 1) * ks);
            }"""

NEW = """            const uint8_t* kp = (const uint8_t*) kcr.data + ((size_t) kvh * ctx + p) * (HD / 2);
            const float ks = __half2float(kcr.scale[(size_t) kvh * ctx + p]);
            // 16-byte loads instead of one byte per load (8 per thread instead of 128): the
            // row stride is 128 bytes and every offset a multiple of it, so a uint4 never
            // crosses a row or a scale. The nibbles unpack in the same dim order and the
            // sum keeps its order, so the output is bit-identical to the byte loop; the
            // L1/L2 transaction count per warp drops 16x (the byte loop's stride-128
            // pattern fetched one byte per 32-byte sector per instruction).
#pragma unroll
            for (int v = 0; v < HD / 32; ++v) {   // 8 x uint4 = 128 bytes = the row
                const uint4 w = __ldg((const uint4*) (kp + v * 16));
                const uint8_t* wb = (const uint8_t*) &w;
#pragma unroll
                for (int u = 0; u < 16; ++u) {
                    const int i = v * 32 + u * 2;
                    a += qs[i] * (kv_q4(wb[u], 0) * ks) + qs[i + 1] * (kv_q4(wb[u], 1) * ks);
                }
            }"""

PATH = "/home/dmin/qwen36-strata-project/src/qwen35/q36_engine.cu"
src = open(PATH, encoding="utf-8").read()
if NEW in src:
    print("already applied")
    sys.exit(0)
n = src.count(OLD)
if n != 1:
    print(f"FAIL: the byte-loop block appears {n} times (expected 1)")
    sys.exit(1)
open(PATH, "w", encoding="utf-8", newline="").write(src.replace(OLD, NEW))
print("patched ok")
