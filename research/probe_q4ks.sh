#!/usr/bin/env bash
# Probe the running Q4_K_S server: log, health, one answer.
echo '== q4ks serve log =='
tail -20 ~/qwen36-strata-project/q4ks-serve.log 2>/dev/null
echo
echo '== q4ks engine log =='
tail -60 ~/qwen36-strata-project/strata-qwen36-q4ks.log 2>/dev/null
echo
echo '== health =='
curl -s -m 5 http://127.1.1:30000/health 2>/dev/null || curl -s -m 5 http://127.0.0.1:30000/health
echo
echo '== one chat answer =='
curl -s -m 60 http://127.0.0.1:30000/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"qwen3.6-35b-a3b","messages":[{"role":"user","content":"hi, one word answer: 2+2="}],"max_tokens":12}' | head -c 1200
echo
echo '== engine process uptime =='
ps -o pid,etime,rss,cmd -p 668 2>/dev/null
echo
echo '== kit bench files =='
ls ~/qwen36-strata-kit/run/ 2>/dev/null | head
echo
echo '== research dir scripts (names only) =='
ls ~/qwen36-strata-project/research/*.sh 2>/dev/null | head -40
