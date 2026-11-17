#!/bin/bash
# Orientation probe on the rig's WSL2 Ubuntu
echo "== whoami / host =="
whoami
uname -srm
echo "== paths =="
ls -d /models/qwen36-heretic/* 2>&1 | head -5
ls -d /opt/strata/venv/bin/python 2>&1
echo "== toolchain =="
which nvcc cmake ninja ccache 2>&1
nvcc --version 2>&1 | tail -1
cmake --version 2>&1 | head -1
echo "== resources =="
nproc
free -m | head -3
df -h /mnt/c 2>&1 | tail -1
echo "== gpu =="
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits 2>&1
echo "== engines / thermite =="
ls "$HOME" 2>&1 | head -20
for p in /opt/strata /opt/thermite /opt/strata/venv; do
  echo "-- $p"
  ls "$p" 2>&1 | head -6
done
echo "== tokenizer =="
ls /models/qwen36-heretic/tokenizer 2>&1 | head -5
echo "== podman quadlet =="
ls ~/.config/containers/systemd/ 2>&1
ls ~/.local/share/thermite 2>&1 | head -5
