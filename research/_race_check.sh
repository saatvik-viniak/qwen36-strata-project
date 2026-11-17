#!/bin/bash
# temp helper: script mtime vs the running q5k process start (the runner2-death risk)
stat -c "script mtime: %y" /mnt/c/Users/Admin/Admin 2>/dev/null
stat -c "cand_q5k_runner.sh mtime: %y" "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/cand_q5k_runner.sh"
ps -o pid,lstart,etime,cmd -p 75866 2>/dev/null || echo "pid 75866 gone"
pgrep -af cand_q5k_runner
