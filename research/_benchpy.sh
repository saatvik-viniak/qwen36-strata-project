#!/bin/bash
# temp helper: bench.py's tokenizer resolution + mtime - why did --model become ''?
B=/home/dmin/qwen36-strata-kit/run/bench.py
echo "== bench.py mtime =="
stat -c "%y %s bytes" "$B"
echo "== bench.py lines 30-50 (main: args -> model_path) =="
sed -n "30,50p" "$B"
echo "== bench.py lines 95-105 (load_tokenizer) =="
sed -n "95,105p" "$B"
echo "== any other bench-ish scripts in the kit (mtimes) =="
ls -la --time-style=+%H:%M /home/dmin/qwen36-strata-kit/run/ 2>/dev/null | head -12
