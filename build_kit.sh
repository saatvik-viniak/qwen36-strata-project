#!/bin/sh
# Kit build: compile the engine in this tree and stage a self-contained build/.
#
# It runs in the source tree as the builder user, so every edit an agent makes to
# src/ (the Qwen3.6 engine path is src/qwen35) is compiled here. The staged build/
# is what the judge runs: serve.sh, the engine binary beside it, and the python
# server the script imports.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT="$ROOT/out"
BUILD="$ROOT/build"
JOBS="${JOBS:-$(nproc)}"

. "$ROOT/cuda_env.sh"
strata_find_cuda || {
  strata_cuda_help
  exit 1
}

# CMake 3.24+ is needed and the rig's build user may have the distro's 3.22
# (Ubuntu 22.04). Fetch a private one instead of touching the system.
cmake_ok() {
  v="$(cmake --version 2>/dev/null | head -1 | awk '{print $3}')"
  [ -n "$v" ] && [ "$(printf '%s\n3.24\n' "$v" | sort -V | head -1)" = "3.24" ]
}
# The judge's build sandbox is not this shell: it has python3 and network but no
# curl, wget or pip. Download with whatever is there.
fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    python3 - "$1" "$2" <<'PY'
import sys, urllib.request
urllib.request.urlretrieve(sys.argv[1], sys.argv[2])
PY
  fi
}
if ! cmake_ok; then
  TC="$ROOT/.toolchain/cmake"
  if [ ! -x "$TC/bin/cmake" ]; then
    v=3.31.6
    mkdir -p "$ROOT/.toolchain"
    echo "system cmake is too old; fetching cmake $v into .toolchain/"
    fetch "https://github.com/Kitware/CMake/releases/download/v${v}/cmake-${v}-linux-x86_64.tar.gz" \
      "$ROOT/.toolchain/cmake.tar.gz"
    tar -xzf "$ROOT/.toolchain/cmake.tar.gz" -C "$ROOT/.toolchain"
    mv "$ROOT/.toolchain/cmake-${v}-linux-x86_64" "$TC"
    rm -f "$ROOT/.toolchain/cmake.tar.gz"
  fi
  PATH="$TC/bin:$PATH"
  export PATH
fi

cmake -G Ninja -S "$ROOT" -B "$OUT" \
  -DCMAKE_BUILD_TYPE=Release \
  -DSTRATA_ENABLE_CUDA=ON \
  -DSTRATA_BUILD_TESTS=OFF \
  -DSTRATA_NATIVE_EXPERTS=ON \
  -DSTRATA_PORTABLE=ON \
  -DSTRATA_Q6K_EXPERTS=ON \
  -DSTRATA_MMQ_KQUANTS=ON \
  -DCMAKE_CUDA_ARCHITECTURES=86-real

cmake --build "$OUT" --target strata -j "$JOBS"

rm -rf "$BUILD"
mkdir -p "$BUILD"

# The python server and the data it reads, without the build tree or the history.
tar -C "$ROOT" \
  --exclude=./.git --exclude=./out --exclude=./build --exclude=./__pycache__ \
  -cf - . | tar -C "$BUILD" -xf -

cp "$OUT/strata" "$BUILD/strata"
cp "$ROOT/serve.sh" "$BUILD/serve.sh"
chmod +x "$BUILD/strata" "$BUILD/serve.sh"
