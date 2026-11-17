#!/bin/bash
# Placement lines from the engine log, newest last (the 262k runs are at the end).
grep -a "strata-q36" /home/dmin/qwen36-strata-project/strata-qwen36.log | tail -30
