#!/bin/bash
# temp helper: the candidate server's placement + load lines (cand_server.log) vs the earlier champion-era lines
grep -a "hybrid experts\|context .* cells\|K-quant prompt kernels\|prompt experts\|MTP block loaded" /home/dmin/qwen36-strata-project/cand_server.log | tail -6
echo "== the engine log's most recent placement lines (262k runs at the end) =="
grep -a "hybrid experts" /home/dmin/qwen36-strata-project/strata-qwen36.log | tail -4
