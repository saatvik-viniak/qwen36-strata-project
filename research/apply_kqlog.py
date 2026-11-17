#!/usr/bin/env python3
"""apply_kqlog.py — the observability fix (SUGGESTIONS.MD, the v6 checklist's follow-up):
log the q5k multi-token kernel's engagement state at load.

The v5 failure class stayed silent because the dispatch state was invisible in the
log (only STRATA_MMQ_KQ lines exist). One line at the gate/up dispatch site
(native_expert.cpp, the kq lambda, once per process) makes every future A/B's log
prove which kernel the cells measured:
    strata: q5k multi-token kernel: engaged/disabled (STRATA_KQ256=…)
No behavior change (a fprintf beside a getenv read); the default path stays
byte-identical. Applied to BOTH trees (the Windows checkout + the WSL clone);
idempotent. Adds <cstdio> if the file somehow lacks it.
"""
import sys

OLD = '    static const bool kq = [] { const char* v = std::getenv("STRATA_KQ256"); return cpu_avx2_ok() && v != nullptr && std::atoi(v) != 0; }();'

NEW = '''    static const bool kq = [] { const char* v = std::getenv("STRATA_KQ256");
      const bool on = cpu_avx2_ok() && v != nullptr && std::atoi(v) != 0;
      std::fprintf(stderr, "strata: q5k multi-token kernel: %s (STRATA_KQ256=%s)\\n",
                   on ? "engaged" : "disabled", v ? v : "unset");
      return on; }();'''

INCLUDE = "#include <cstdio>"

for path in ("/home/dmin/qwen36-strata-project/src/kernels/cpu/native_expert.cpp",
             "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/src/kernels/cpu/native_expert.cpp"):
    try:
        src = open(path, encoding="utf-8").read()
    except OSError as e:
        print(f"SKIP ({path}: {e})")
        continue
    if NEW in src:
        print(f"already applied: {path}")
        continue
    n = src.count(OLD)
    if n != 1:
        print(f"FAIL: the kq lambda appears {n} times in {path} (expected 1)")
        sys.exit(1)
    if INCLUDE not in src and "<stdio.h>" not in src:
        i = src.index("#include")
        end = src.index("\n", i)
        src = src[:end + 1] + INCLUDE + "\n" + src[end + 1:]
        print(f"added {INCLUDE} to {path}")
    open(path, "w", encoding="utf-8", newline="").write(src.replace(OLD, NEW))
    print(f"apply_kqlog ok: {path}")
