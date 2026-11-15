#!/bin/sh
# Run once on the rig (Windows/WSL) before the first build or campaign.
#
# It installs the build toolchain, a Python environment at /opt/strata that the
# judge's run user can read, and checks that the engine compiles here at all.
# It does not download models; download_model.sh does that.
set -eu

SHARED="${SHARED:-/opt/strata}"
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

sudo apt-get update
sudo apt-get install -y \
  build-essential cmake ninja-build git curl \
  python3-venv python3-dev \
  pkg-config libcurl4-openssl-dev

PYVER="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
sudo apt-get install -y "python${PYVER}-dev" || true

# nvcc must be on the path for the CUDA build; the toolkit is already on the box
# (the 3070 reports CUDA 12.6).
command -v nvcc >/dev/null || {
  echo "nvcc not on PATH: point PATH at the CUDA toolkit bin and run again" >&2
  exit 1
}

sudo mkdir -p "$SHARED"
sudo chown "$USER" "$SHARED"

python3 -m venv "$SHARED/venv"
"$SHARED/venv/bin/pip" install -U pip
"$SHARED/venv/bin/pip" install -r "$ROOT/requirements.txt"

# One compile here, so a broken toolchain is found now and not inside a campaign.
JOBS="$(nproc)" sh "$ROOT/build_kit.sh"

# The judge runs as its own user, not yours.
chmod -R a+rX "$SHARED" "$ROOT"

echo
echo "engine:   $ROOT/build/strata"
echo "python:   $SHARED/venv/bin/python"
echo "serve:    $ROOT/build/serve.sh"
