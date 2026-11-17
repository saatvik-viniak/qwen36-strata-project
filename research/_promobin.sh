#!/bin/bash
# temp helper: what is the promotion pass actually serving? (md5 receipt)
R=/home/dmin/qwen36-strata-project
md5sum "$R/out/strata" "$R/out/strata_q5k_cand" "$R/out/strata_byte_loop" 2>/dev/null
ls -la --time-style=+%H:%M:%S "$R/out/strata" 2>/dev/null
