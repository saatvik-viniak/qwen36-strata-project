#!/bin/bash
# temp helper: the vendored ggml's GGUF value-type enum (the authoritative dialect)
grep -rn "GGUF_TYPE\|gguf_vtype\|value_type" /home/dmin/qwen36-strata-project/third_party/strata-ggml/ggml/src/gguf*.{c,h} 2>/dev/null | head -30
ls /home/dmin/qwen36-strata-project/third_party/strata-ggml/ggml/src/ | grep -i gguf
