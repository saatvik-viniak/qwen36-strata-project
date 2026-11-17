#!/bin/bash
cd ~/qwen36-strata-project/.oc || exit 0
echo "== full .oc listing =="
ls -la | head -60
echo ""
echo "== run_verify.sh =="
cat run_verify.sh 2>/dev/null | head -30
echo ""
echo "== run_verify2.sh =="
cat run_verify2.sh 2>/dev/null | head -30
echo ""
echo "== answer_int4_32768.log (tail) =="
tail -25 answer_int4_32768.log 2>/dev/null
echo ""
echo "== answer_int4_131072.log (tail) =="
tail -25 answer_int4_131072.log 2>/dev/null
