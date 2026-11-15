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
