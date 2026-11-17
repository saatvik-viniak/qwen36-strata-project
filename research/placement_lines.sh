#!/bin/bash
# placement_lines.sh — compare hybrid/MMQ placement lines across the whole engine log.
L=/home/dmin/qwen36-strata-project/strata-qwen36.log
grep -nE "hybrid experts|prompt experts|MMQ|mmq" "$L" | tail -40
