#!/bin/bash
# temp helper: confirm out/strata is the compose binary (the new gate's target)
R=/home/dmin/qwen36-strata-project
md5sum "$R/out/strata" "$R/out/strata_q5k_cand" "$R/out/strata_byte_loop" 2>/dev/null
