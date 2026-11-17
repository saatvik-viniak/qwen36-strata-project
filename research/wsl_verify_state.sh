#!/bin/bash
echo "== .oc contents (main clone) =="
find ~/qwen36-strata-project/.oc -maxdepth 3 2>/dev/null | head -20
echo "== does out/strata contain --kv? =="
grep -c -- "--kv" ~/qwen36-strata-project/out/strata 2>/dev/null || echo "grep count failed"
strings ~/qwen36-strata-project/out/strata 2>/dev/null | grep -m2 -- "--kv"
echo "== compare: dirty diff vs lane commit a64a20b =="
cd ~/qwen36-strata-project
git diff > /tmp/dirty.diff
cd ~/agent-1-lane
git diff d548533 a64a20b > /tmp/lane.diff
if cmp -s /tmp/dirty.diff /tmp/lane.diff; then
  echo "IDENTICAL: the dirty tree equals the lane commit"
else
  echo "DIFFERENT:"
  echo "dirty lines: $(wc -l < /tmp/dirty.diff), lane lines: $(wc -l < /tmp/lane.diff)"
  diff /tmp/dirty.diff /tmp/lane.diff | head -20
fi
echo "== disk space =="
df -h / /tmp 2>&1 | head -4
echo "== ccache size =="
du -sh ~/.cache/ccache 2>/dev/null || du -sh ~/.ccache 2>/dev/null || echo none
echo "== git identity in clones =="
cd ~/qwen36-strata-project && git config user.name; git config user.email
cd ~/agent-1-lane && git log -1 --format="author: %an <%ae>%ncommitter: %cn <%ce>%nsubject: %s" a64a20b
echo "== history dir hints =="
ls ~/qwen36-strata-project/history/tools 2>/dev/null | head -5
ls ~/qwen36-strata-project/docs/work 2>/dev/null | head -10
