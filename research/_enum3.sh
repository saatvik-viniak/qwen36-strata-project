#!/bin/bash
grep -rn "GGUF_TYPE_ARRAY\|enum gguf_type" /home/dmin/qwen36-strata-project/third_party/strata-ggml/ggml/include/*.h /home/dmin/qwen36-strata-project/third_party/strata-ggml/ggml/src/*.h 2>/dev/null | head -5
grep -rn -A20 "enum gguf_type {" /home/dmin/qwen36-strata-project/third_party/strata-ggml 2>/dev/null | head -24
