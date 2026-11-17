#!/usr/bin/env python3
"""apply_pinerr.py — S11 lever 1: log the swallowed cudaHostAlloc failure on the WSL clone.

One diagnostic line (no behavior change): when the 21.14 GiB expert arena's pin
attempt fails, print the CUDA error string instead of discarding it. Reveals WHY
the pool has run in pageable memory (a WSL2 page-locked cap = not fixable;
fragmentation or a reserve = fixable). Idempotent; independent of the uint4
patch hunk, so it applies cleanly on top of the clone's current tree state.
"""
import sys

OLD = """    uint8_t* arena = nullptr;
    bool pinned = cudaHostAlloc((void**) &arena, host, cudaHostAllocDefault) == cudaSuccess;
    if (!pinned) {
        (void) cudaGetLastError();
        arena = (uint8_t*) std::malloc(host);"""

NEW = """    uint8_t* arena = nullptr;
    bool pinned = cudaHostAlloc((void**) &arena, host, cudaHostAllocDefault) == cudaSuccess;
    if (!pinned) {
        // S11 lever 1 (diagnostic): the pin failure used to be swallowed silently - the
        // pool has run 21.14 GiB in PAGEABLE memory the whole session (6.2 GB/s effective,
        // 12% of DDR4 peak). Log WHY it fails (a WSL2 page-locked cap is not fixable;
        // fragmentation or a reserve might be): one line, no behavior change.
        const char* perr = cudaGetErrorString(cudaGetLastError());
        std::fprintf(stderr, "strata-q36: cudaHostAlloc for the %.2f GiB expert arena FAILED (%s); "
                     "the pool runs in pageable host memory\\n", (double) host / (1 << 30), perr);
        arena = (uint8_t*) std::malloc(host);"""

PATH = "/home/dmin/qwen36-strata-project/src/qwen35/q36_engine.cu"
src = open(PATH, encoding="utf-8").read()
if NEW in src:
    print("already applied")
    sys.exit(0)
n = src.count(OLD)
if n != 1:
    print(f"FAIL: the pre-edit block appears {n} times (expected 1)")
    sys.exit(1)
open(PATH, "w", encoding="utf-8", newline="").write(src.replace(OLD, NEW))
print("apply_pinerr ok")
