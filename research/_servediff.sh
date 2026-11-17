#!/bin/bash
# temp helper: diff the q5k candidate serve script vs the champion's (A/B fairness)
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
cd "$WS/research"
echo "== serve_262k_q5k.sh =="
cat serve_262k_q5k.sh
echo ""
echo "== diff vs serve_262k.sh =="
diff serve_262k.sh serve_262k_q5k.sh && echo "(identical)" || true
