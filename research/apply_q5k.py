#!/usr/bin/env python3
"""apply_q5k.py — patch the WSL clone with the Q5_K multi-token AVX-2 kernel (S1/PLAN #7).

The clone's CPU kernel sources are byte-identical to the canonical checkout's
HEAD state the patch was written against (verified by md5), so this copies the
patched files over and refuses anything else. Idempotent: skips files whose
target state is already in place. Files:
  src/kernels/cpu/kq_avx2.cpp            q5k_dot<NT> + dot_rows case 13
  src/kernels/cpu/native_expert.cpp      kq256_supported += 13; gu/down dispatch += type 13
  src/kernels/native_expert_parity.cpp   role-0 coverage for type 13
 4th: include/strata/kernels/cpu/kq_avx2.hpp (doc line)
Dispatch stays behind STRATA_KQ256 (default off), so a build containing it does
not change the default path.
"""
import hashlib
import sys

WS_WSL = "/home/dmin/qwen36-strata-project"
WS_WIN = "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project"

# rel path -> (md5 of the pre-edit state, md5 of the patched state)
FILES = {
    "src/kernels/cpu/kq_avx2.cpp":
        ("b19ee460211291e18f0996f80dec4094", "f1984db86e7ed2c442629c985f29a48b"),
    "src/kernels/cpu/native_expert.cpp":
        ("1af0beaffc7c312da230dc6d236f9243", "c608a91eb7b7a146cd197a78266a763c"),
        # patched state now includes the kq engagement log line (apply_kqlog.py,
        # 2026-11-17): the md5 guard refuses unknown states by design, so the
        # observability edit is folded into the expected patched state — the copy
        # source (the Windows checkout's file) carries both the q5k dispatch and
        # the log line (md5 verified identical on both trees).
    "src/kernels/native_expert_parity.cpp":
        ("a1dcc814682e75ad37cced209c3ef256", "e9843fc079c8b921567131f2d56c31e6"),
    "include/strata/kernels/cpu/kq_avx2.hpp":
        ("", "660af9f8b041c55b96cf2777672c2d92"),  # pre-state not hashed; copy when target != patched
}

def md5(b: bytes) -> str:
    return hashlib.md5(b).hexdigest()

bad = []
for rel, (pre, patched) in FILES.items():
    dst = f"{WS_WSL}/{rel}"
    src = f"{WS_WIN}/{rel}"
    cur = md5(open(dst, "rb").read())
    if cur == patched:
        print(f"already applied: {rel}")
        continue
    if pre and cur != pre:
        bad.append(f"{rel}: unexpected state {cur}")
        continue
    open(dst, "wb").write(open(src, "rb").read())
    print(f"patched: {rel}")
if bad:
    print("FAIL: " + "; ".join(bad))
    sys.exit(1)
print("apply_q5k ok")
