#!/bin/bash
# clone_prep.sh — confirm the clone's byte-loop code matches, and find the VERIFY + build mechanisms.
C=/home/dmin/qwen36-strata-project
cd "$C" || exit 1
echo "== byte-loop present in clone? =="
grep -n "const uint8_t b = kp\[i >> 1\];" src/qwen35/q36_engine.cu
echo ""
echo "== VERIFY mechanism =="
grep -rn "VERIFY" src/qwen35/q36_engine.cu | head -5
echo ""
echo "== build entry =="
ls build_kit.sh CMakeLists.txt 2>/dev/null
ls out/strata 2>/dev/null
echo ""
echo "== existing build dir =="
ls -d build 2>/dev/null && ls build/build.ninja 2>/dev/null | head -2
