#!/bin/sh
# Sourced by build_kit.sh and setup_rig.sh. Finds the CUDA toolkit nvcc needs.
#
# WSL and the distro packages install the toolkit in a versioned folder that is
# not on PATH, so `command -v nvcc` alone is not enough.
strata_find_cuda() {
  if [ -n "${CUDA_HOME:-}" ] && [ -x "${CUDA_HOME}/bin/nvcc" ]; then
    PATH="${CUDA_HOME}/bin:${PATH}"
    export CUDA_HOME PATH
    return 0
  fi
  for c in /usr/local/cuda-12.9 /usr/local/cuda-12.8 /usr/local/cuda-12.7 \
           /usr/local/cuda-12.6 /usr/local/cuda-12.5 /usr/local/cuda-12.4 \
           /usr/local/cuda /opt/cuda /usr/lib/cuda /usr/lib/nvidia/cuda; do
    if [ -x "${c}/bin/nvcc" ]; then
      CUDA_HOME="$c"
      PATH="${c}/bin:${PATH}"
      export CUDA_HOME PATH
      return 0
    fi
  done
  if command -v nvcc >/dev/null 2>&1; then
    CUDA_HOME="$(dirname "$(dirname "$(command -v nvcc)")")"
    PATH="${CUDA_HOME}/bin:${PATH}"
    export CUDA_HOME PATH
    return 0
  fi
  return 1
}

strata_cuda_help() {
  cat >&2 <<'EOF'
No CUDA toolkit (nvcc) found. The driver alone is not enough to build the engine.

Install the toolkit, then run this script again:

  wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
  sudo dpkg -i cuda-keyring_1.1-1_all.deb
  sudo apt-get update
  sudo apt-get install -y cuda-toolkit-12-6

Or point CUDA_HOME at an existing toolkit:

  CUDA_HOME=/usr/local/cuda-12.6 ./setup_rig.sh

`nvidia-smi` printing a CUDA version only means the driver is installed.
EOF
}
