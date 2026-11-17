#!/bin/bash
echo "== wsl clone state =="
cd ~/qwen36-strata-project 2>/dev/null || { echo "no clone"; exit 0; }
git log --oneline -5 2>&1
git status -sb 2>&1 | head -10
git remote -v 2>&1 | head -4
echo "== built engines =="
ls -la out/strata build/strata 2>&1 | head -6
ls -la build/ 2>&1 | head -10
echo "== kit clone =="
cd ~/qwen36-strata-kit 2>/dev/null && git log --oneline -3 2>&1 && ls 2>&1 | head -10
echo "== agent-1-lane =="
ls ~/agent-1-lane 2>&1 | head -10
echo "== thermite infra =="
ls ~/.config/containers/systemd/ 2>&1
ls -la ~/.local/share/thermite/ 2>&1 | head -10
command -v podman && podman ps -a 2>&1 | head -10
systemctl --user list-units 2>/dev/null | grep -i thermite | head -5
echo "== ports =="
ss -tlnp 2>/dev/null | grep -E '8800|30000|8080|9000' | head -10
echo "== running engines? =="
pgrep -af strata | head -5
pgrep -af thermite | head -5
echo "== cuda toolkit location =="
ls /usr/local/ 2>&1 | head -8
ls /usr/local/cuda/bin/nvcc 2>&1
ls /usr/lib/cuda/bin/nvcc 2>&1
