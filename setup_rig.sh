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
  strata_cuda_help
  exit 1
}
echo "CUDA toolkit: $CUDA_HOME ($("$CUDA_HOME/bin/nvcc" --version | tail -1))"

sudo mkdir -p "$SHARED"
sudo chown "$USER" "$SHARED"

python3 -m venv "$SHARED/venv"
"$SHARED/venv/bin/pip" install -U pip
"$SHARED/venv/bin/pip" install -r "$ROOT/requirements.txt"

JOBS="$(nproc)" sh "$ROOT/build_kit.sh"

# The judge runs as its own user, not yours.
chmod -R a+rX "$SHARED" "$ROOT"

echo
echo "engine:   $ROOT/build/strata"
echo "python:   $SHARED/venv/bin/python"
echo "serve:    $ROOT/build/serve.sh"
"$ROOT/build/strata" --families 2>/dev/null | tr ' ' '\n' | grep -qx qwen35moe \
  && echo "family:   qwen35moe compiled in"
