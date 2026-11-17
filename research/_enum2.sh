#!/bin/bash
grep -n "enum\|STRING\|FLOAT32\|FLOAT64\|ARRAY\|BOOL\|UINT8\|UINT64" /home/dmin/qwen36-strata-project/third_party/strata-ggml/ggml/src/gguf.cpp | head -25
echo "== the type-8/9/10 handling in the reader =="
grep -n "case 8\|case 9\|case 10\|case 11\|case 12\|GGUF_TYPE" /home/dmin/qwen36-strata-project/third_party/strata-ggml/ggml/src/gguf.cpp | head -20
