#!/bin/bash
cd /home/dmin/qwen36-strata-project/out || exit 1
echo "== binaries: size + full mtime =="
ls -l --time-style=full-iso strata strata_q5k_cand strata_q5k_base strata_byte_loop 2>/dev/null
echo "== md5 again =="
md5sum strata strata_q5k_cand strata_q5k_base strata_byte_loop 2>/dev/null
echo "== any other out/ artifacts =="
ls -l --time-style=full-iso | tail -15
echo "== engine build dirs in the clone =="
cd /home/dmin/qwen36-strata-project || exit 1
ls -d build* parity_build 2>/dev/null
for d in build parity_build; do
  [ -d "$d" ] && find "$d" -name "*.o" -newer /home/dmin/qwen36-strata-project/out/strata_byte_loop 2>/dev/null | head -5
done
echo "== the patched sources' mtimes =="
ls -l --time-style=full-iso src/qwen35/q36_engine.cu src/qwen35/*.cu 2>/dev/null | head -8
