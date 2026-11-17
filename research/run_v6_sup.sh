#!/bin/bash
# run_v6_sup.sh — supervisor for cand_q5k_runner.sh (v6).
# The 07:58Z launch died at the wsl client's 4 s exit DESPITE setsid nohup (the
# detach survived at 06:33Z/06:45Z but not here — WSL session teardown is
# nondeterministic). This supervisor keeps the wsl client alive for the chain's
# whole life: the background shell job runs this script, this script holds the
# client while the chain runs detached, and the job completes when the chain
# exits (or after 2 h 15 m — the chain's expected life is ~60-70 min).
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
setsid nohup bash "$WS/research/cand_q5k_runner.sh" > /home/dmin/qwen36-strata-project/cand_q5k_launch.log 2>&1 < /dev/null &
for i in $(seq 1 540); do
  ps aux --width 250 | grep -q "cand_q5k_runner" || { echo "chain exited after $i polls"; exit 0; }
  sleep 15
done
echo "supervisor timeout (the chain may still be running)"
