#!/bin/bash
tail -3 /mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/cand_q5k.log
ps aux --width 250 | grep cand_q5k_runner | grep -v grep | head -1
