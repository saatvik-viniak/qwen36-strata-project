#!/usr/bin/env python3
"""apply_poolms.py — Lever A: the STRATA_POOLMS per-step pool accounting patch.

Adds to ExpertPool::run_split_multi_native (src/kernels/cpu/pool.cpp):
  (1) a function-local static gate (STRATA_POOLMS=1; the kqlog precedent:
      default OFF — byte-identical outputs and behavior when unset);
  (2) per-call before-snapshots of the member phase accumulators
      (ms_multi_gu/q/down), so the call's per-phase totals come from the
      existing member deltas without touching the batch loop;
  (3) at the tail: ms_drain_call computed ONCE (the same clock sample is
      reused for ms_drain_, so the member's value stays exact) + one
      env-gated fprintf
      'strata pool-ms: <ms> (gu/q/down), N experts, MB, GB/s'
      using the existing per-call bytes n * f.bytes (GB/s = bytes/ms / 1e6).

md5-guarded: both trees (the WSL clone = the build source; the C: checkout =
the committed source) must be md5-identical BEFORE the patch; the patch is
applied to BOTH so the built source and the committed source stay the same.
Each anchor must appear exactly once; a second application is refused.
"""
import hashlib
import sys

HEAD_OLD = """void ExpertPool::run_split_multi_native(const NativeFmt& f, ExpertJobMulti* jobs, int n, NativeArithmetic arithmetic) {
    if (n <= 0) return;
    const auto t0 = std::chrono::steady_clock::now();
"""

HEAD_NEW = """void ExpertPool::run_split_multi_native(const NativeFmt& f, ExpertJobMulti* jobs, int n, NativeArithmetic arithmetic) {
    if (n <= 0) return;
    static const bool s_poolms = [] { const char* e = std::getenv("STRATA_POOLMS"); return e && *e == '1'; }();
    const double gu_before = ms_multi_gu, q_before = ms_multi_q, down_before = ms_multi_down;
    const auto t0 = std::chrono::steady_clock::now();
"""

TAIL_OLD = """        ms_multi_gu += std::chrono::duration<double, std::milli>(b - a).count();
        ms_multi_q += std::chrono::duration<double, std::milli>(c - b).count();
        ms_multi_down += std::chrono::duration<double, std::milli>(d - c).count();
    }
    multi_bytes += (int64_t) n * (int64_t) f.bytes;
    mode_ = 0;
    ms_drain_ += std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
}
"""

TAIL_NEW = """        ms_multi_gu += std::chrono::duration<double, std::milli>(b - a).count();
        ms_multi_q += std::chrono::duration<double, std::milli>(c - b).count();
        ms_multi_down += std::chrono::duration<double, std::milli>(d - c).count();
    }
    const double ms_drain_call = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
    multi_bytes += (int64_t) n * (int64_t) f.bytes;
    mode_ = 0;
    ms_drain_ += ms_drain_call;
    if (s_poolms) {
        const double bytes_call = (double) n * (double) f.bytes;
        std::fprintf(stderr,
                     "strata pool-ms: %.1f ms (gu %.1f / q %.1f / down %.1f), %d experts, %.1f MB, %.2f GB/s\\n",
                     ms_drain_call, ms_multi_gu - gu_before, ms_multi_q - q_before,
                     ms_multi_down - down_before, n, bytes_call / (1024.0 * 1024.0),
                     ms_drain_call > 0.0 ? bytes_call / ms_drain_call / 1e6 : 0.0);
    }
}
"""

TREES = [
    "/home/dmin/qwen36-strata-project/src/kernels/cpu/pool.cpp",
    "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/src/kernels/cpu/pool.cpp",
]


def md5(path):
    with open(path, "rb") as fh:
        return hashlib.md5(fh.read()).hexdigest()


def read_norm(path):
    """The file's content with CRLF normalized to LF: the C: checkout's
    working copy carries autocrlf's CRLF; the build source (the WSL clone)
    is LF-only. The trees are compared after normalization."""
    with open(path, "rb") as fh:
        return fh.read().replace(b"\r\n", b"\n")


def main():
    blobs = [read_norm(t) for t in TREES]
    if blobs[0] != blobs[1]:
        sys.exit(f"TREE MISMATCH (after CRLF->LF normalization): {[md5(t) for t in TREES]}")
    src = blobs[0].decode("utf-8")
    if "s_poolms" in src or "pool-ms" in src:
        sys.exit("UNEXPECTED STATE: the patch seems already applied (s_poolms/pool-ms present)")
    for name, anchor in (("HEAD", HEAD_OLD), ("TAIL", TAIL_OLD)):
        count = src.count(anchor)
        if count != 1:
            sys.exit(f"UNEXPECTED STATE: anchor {name}: expected 1 occurrence, found {count}")
    src = src.replace(HEAD_OLD, HEAD_NEW)
    src = src.replace(TAIL_OLD, TAIL_NEW)
    for tree in TREES:
        with open(tree, "wb") as fh:
            fh.write(src.encode("utf-8"))   # LF to both trees (the repo's canonical form)
    print("patched OK (both trees; LF written)")
    for tree in TREES:
        print(f"{md5(tree)}  {tree}")


if __name__ == "__main__":
    main()
