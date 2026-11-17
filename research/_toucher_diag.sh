#!/bin/sh
# _toucher_diag.sh — the TOUCHER_SPEC step-0 snapshot (read-only /proc + dmesg).
# Usage: _toucher_diag.sh before|after  (run before/after an idle >=900 s window)
PID=$(pgrep -f out/strata | head -1)
echo "== toucher diag $1 $(date -u +%F_%TZ) pid=$PID =="
if [ -z "$PID" ]; then echo "no engine pid"; exit 0; fi
grep -E '^(VmRSS|VmSwap|SwapTotal|SwapFree):' /proc/$PID/status
cat /proc/swaps
dmesg 2>/dev/null | grep -iE 'MemoryReclaim|drop_caches' | tail -3
# per-mapping swapped bytes (kB -> MiB), only the blocks with swap != 0
awk '/^[0-9a-f]+-/ { if (sw != 0) printf "mapping %s %s: swapped %.1f MiB\n", rng, perms, sw/1024; split($0, a, " "); rng=a[1]; perms=a[2]; sw=0; next } /^Swap:/ { sw += $2; next } END { if (sw != 0) printf "mapping %s %s: swapped %.1f MiB\n", rng, perms, sw/1024 }' /proc/$PID/smaps
echo "== end $1 =="
