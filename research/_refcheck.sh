#!/usr/bin/env bash
echo '== q4ks_ref_launch.log =='
cat /home/dmin/qwen36-strata-project/q4ks_ref_launch.log 2>/dev/null || echo none
echo
echo '== q4ks_ref bench.log tail =='
tail -8 /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/q4ks_ref/bench.log 2>/dev/null || echo none
echo
echo '== q4ks_ref jsons =='
ls -la /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/q4ks_ref/ 2>/dev/null
