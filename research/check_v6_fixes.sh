#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
grep -a "v6 up\|uint4 bench done\|verdict\|kernel applied\|base binary preserved\|out/strata removed\|build ok\|BUILD NO-OP\|DISTINCT\|candidate binary kept\|no work to do\|server stopped for the parity\|parity build ok\|PARITY RUN" "$WS/research/cand_q5k.log"
echo "== binary md5 check (cand must differ from base) =="
cd /home/dmin/qwen36-strata-project/out && md5sum strata strata_q5k_cand strata_q5k_base strata_byte_loop
ls -l --time-style=full-iso strata strata_q5k_cand
