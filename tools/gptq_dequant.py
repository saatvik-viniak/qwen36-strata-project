#!/usr/bin/env python3
"""Dequantize a GPTQ checkpoint to a dense bf16 Transformers directory.

Used by prepare_model.sh. GPTQModel's dequantizer reads the packed qweight /
qzeros / scales / g_idx tensors and writes ordinary bf16 safetensors plus a
config.json without quantization_config, which is what llama.cpp's converter
needs.
"""
from __future__ import annotations

import sys

import torch
from gptqmodel.utils.model_dequant import dequantize_model


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: gptq_dequant.py <gptq-dir> <out-dir> [--resume]", file=sys.stderr)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    resume = "--resume" in sys.argv[3:]
    print(f"dequantizing {src} -> {dst} (bf16, {torch.get_num_threads()} threads)", flush=True)
    dequantize_model(
        src,
        dst,
        target_dtype=torch.bfloat16,
        trust_remote_code=True,
        resume=resume,
    )
    print("dequantized", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
