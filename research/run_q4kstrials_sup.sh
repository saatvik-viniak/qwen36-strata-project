#!/bin/bash
# run_q4kstrials_sup.sh — supervisor for the Q4_K_S trial chain: T1 (the mtpoff
# isolation) then T2 (the poolms capture), run sequentially in one foreground
# wrapper (one GPU; never parallel). The wrapper runs the two trial scripts
# themselves (each waits on its predecessor's marker), so holding this client
WS=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project
setsid nohup bash -c "bash $WS/research/q4ks_trial_mtpoff.sh; bash $WS/research/q4ks_trial_poolms.sh" > /home/dmin/qwen36-strata-project/q4ks_trials_chain.log 2>&1 < /dev/null &
for i in $(seq 1 1200); do
  ps aux --width 250 | grep -q "q4ks_trial" || { echo "q4ks trials chain exited after $i polls"; exit 0; }
  sleep 15
done
echo "supervisor timeout (the chain may still be running)"
