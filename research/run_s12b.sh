#!/bin/bash
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
LOG=$WS/research/s12b.log
echo "== s12b up $(date -u +%F_%TZ) ==" > "$LOG"
bash "$WS/research/stop_server.sh" >> "$LOG" 2>&1 || true
sleep 5
echo "== free before ==" >> "$LOG"
free -m | head -2 >> "$LOG"
cd /home/dmin/qwen36-strata-project || exit 1
if gcc -O2 -pthread -o s12b_mb "$WS/research/s12b_microbench.c" >> "$LOG" 2>&1; then
  echo "compile ok $(date -u +%F_%TZ)" >> "$LOG"
else
  echo "COMPILE FAILED $(date -u +%F_%TZ)" >> "$LOG"
  tail -20 "$LOG"
  exit 1
fi
./s12b_mb >> "$LOG" 2>&1
echo "== free after ==" >> "$LOG"
free -m | head -2 >> "$LOG"
echo "== s12b done $(date -u +%F_%TZ) =="
cat "$LOG"
