#!/usr/bin/env python3
import json
GGUF = "/models/qwen36-heretic/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-Q5_K_S.gguf"
try:
    from gguf import GGUFReader
    r = GGUFReader(GGUF)
    meta = {}
    for k, v in r.meta_array() if False else []:
        pass
    md = {k: v for k, v in zip([x for x in []], [])}  # placeholder
    try:
        meta = {k: (v.tolist() if hasattr(v, 'tolist') else v) for k, v in r.metadata.items()}
    except Exception as e:
        meta = {"err": str(e)}
    print(json.dumps({k: (str(v)[:120]) for k, v in meta.items()}, indent=1, sort_keys=True))
    # tensor sizes
    import numpy as np
    roles = {}
    from collections import defaultdict
    sizes = defaultdict(float)
    for t in r.tensors:
        name = t.name
        try:
            n = int(abs(t.data.nbytes)) if hasattr(t, 'data') else None
        except Exception:
            n = None
        if n is None:
            # compute from shape and dtype
            shp = t.shape if hasattr(t, 'shape') else None
            n = None
        if n:
            ln = name.lower()
            key = ('routed_experts' if ('expert' in ln or 'dex' in ln) else
                   'attention' if 'attn' in ln else
                   'ssm_gdn' if ('ssm' in ln or 'gdn' in ln or 'conv' in ln) else
                   'router' if 'router' in ln else
                   'shared' if 'shared' in ln else
                   'head' if ('output' in ln or 'head' in ln) else 'other')
            sizes[key] += n / 1e9
    print(json.dumps({k: round(v, 3) for k, v in sizes.items()}, indent=1))
except ImportError as e:
    print("NO gguf package:", e)
