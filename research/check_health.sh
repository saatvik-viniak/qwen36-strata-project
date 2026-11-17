#!/bin/sh
# One-shot champion health probe. Usage: wsl -d Ubuntu sh -c 'bash /mnt/c/.../research/check_health.sh'
H=$(curl -s --max-time 5 'http://127.0.0.1:30000/health' || true)
if [ -z "$H" ]; then
  echo "DOWN"
else
  echo "$H"
fi
# how many serve-tree processes are alive
pgrep -f 'strata_serve|serve_262k' >/dev/null 2>&1 && echo "serve-tree: alive" || echo "serve-tree: none"
