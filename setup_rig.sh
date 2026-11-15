#!/bin/sh
# Run once on the rig (Windows/WSL) before the first build or campaign.
#
# Installs the build toolchain, a Python environment at /opt/strata the judge's
# run user can read, and compiles the engine here so a broken toolchain is found
# outside a campaign.
set -eu

SHARED="${SHARED:-/opt/strata}"
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$ROOT/cuda_env.sh"

sudo apt-get update
sudo apt-get install -y \
  build-essential cmake ninja-build git curl ca-certificates \
  python3-venv python3-dev pkg-config libcurl4-openssl-dev

PYVER="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
sudo apt-get install -y "python${PYVER}-dev" || true

strata_find_cuda || {
  # WSL and Ubuntu installs have no toolkit with the driver; the engine's KQUANT /
  # MMQ kernels are compiled from source, so nvcc has to exist.
  if grep -qi ubuntu /etc/os-release 2>/dev/null; then
    if grep -qi microsoft /proc/version 2>/dev/null; then
      repo="wsl-ubuntu"
    else
      ver="$(. /etc/os-release; echo "${VERSION_ID//./}")"
      repo="ubuntu${ver}"
    fi
    echo "No CUDA toolkit found; installing cuda-toolkit-12-6 from the NVIDIA ${repo} repo"
    echo "(several GB; the first build needs it)"
    tmp="$(mktemp -d)"
    if wget -q -O "$tmp/cuda-keyring.deb" \
        "https://developer.download.nvidia.com/compute/cuda/repos/${repo}/x86_64/cuda-keyring_1.1-1_all.deb"; then
      sudo dpkg -i "$tmp/cuda-keyring.deb"
      sudo apt-get update
      sudo apt-get install -y cuda-toolkit-12-6
    fi
    rm -rf "$tmp"
  fi
  strata_find_cuda || {
    strata_cuda_help
    exit 1
  }
}
echo "CUDA toolkit: $CUDA_HOME ($("$CUDA_HOME/bin/nvcc" --version | tail -1))"

sudo mkdir -p "$SHARED"
sudo chown "$USER" "$SHARED"

python3 -m venv "$SHARED/venv"
"$SHARED/venv/bin/pip" install -U pip
"$SHARED/venv/bin/pip" install -r "$ROOT/requirements.txt"
"$SHARED/venv/bin/pip" install "huggingface_hub[cli]"

JOBS="$(nproc)" sh "$ROOT/build_kit.sh"

# The judge runs as its own user, not yours.
chmod -R a+rX "$SHARED" "$ROOT"

echo
echo "engine:   $ROOT/build/strata"
echo "python:   $SHARED/venv/bin/python"
echo "serve:    $ROOT/build/serve.sh"
"$ROOT/build/strata" --families 2>/dev/null | tr ' ' '\n' | grep -qx qwen35moe \
  && echo "family:   qwen35moe compiled in"
