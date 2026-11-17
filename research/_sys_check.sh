#!/bin/bash
# temp helper: check for stray strata processes + RAM/swap state on the WSL box
echo "== strata processes =="
ps aux | grep -v grep | grep -i strata || echo "none found via ps"
echo "== memory =="
free -m
echo "== swap =="
swapon --show 2>/dev/null || echo "no swap active"
echo "== top 8 by RSS =="
ps aux --sort=-rss | head -9
