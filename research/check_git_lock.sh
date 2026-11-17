#!/bin/bash
L=/mnt/c/Users/Admin/Auto-research-agent/Runtime/projects/saatvik-viniak/qwen36-strata-project/.git/index.lock
if [ -f "$L" ]; then
  stat -c "lock mtime: %y" "$L"
  echo "now: $(date -u +%F_%TZ)"
else
  echo "no lock"
fi
