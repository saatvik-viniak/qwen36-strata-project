#!/bin/bash
sleep 2400
/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/_verdicts.sh
echo "== the base leg's results =="
for f in empty.json ctx32k.json ctx128k.json; do
  p="/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/promotion_base/$f"
  [ -f "$p" ] && echo "$f: $(grep -o "\"decode_tps\": [0-9.]*" "$p" | head -1)" || echo "$f: absent"
done
[ -f "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/promotion_base.done" ] && cat "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/promotion_base.done" || echo "(promotion_base.done absent)"
tail -6 "/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/research/promotion_base.log"
