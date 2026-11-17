#!/bin/bash
# temp helper for the suggestions agent: pull draft-acceptance lines from the engine log (WSL clone)
grep -n -i "draft" /home/dmin/qwen36-strata-project/strata-qwen36.log | tail -25
