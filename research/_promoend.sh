#!/bin/bash
# temp helper: the promotion pass's final state (which branch did it take?)
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
echo "== promotion.log tail =="
tail -14 "$WS/research/promotion.log"
echo ""
echo "== promotion/ dir contents =="
ls -la "$WS/research/promotion/" 2>/dev/null
echo "== champion serving? (the port + the binary) =="
md5sum /home/dmin/qwen36-strata-project/out/strata
