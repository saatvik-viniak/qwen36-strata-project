# _q4ks_t2_analyze.ps1 — the Q4_K_S poolms capture analysis (the pre-registered
# protocol, the session-line split NOT SUM/2). Reads the LIVE engine log's LAST
# engine-start block (the poolms serve), splits the pool-ms lines by the session
# lines, reports per segment: SUM ms, the phases, the experts/call, the MB, the
# aggregate GB/s, the share of the decode, the stall histogram (>10 ms), and the
# call-model check via the drafts count (steps = drafts/2 at MTP 2).
$p = '\\wsl.localhost\Ubuntu\home\dmin\qwen36-strata-project\strata-qwen36-q4ks262.log'
$all = [System.IO.File]::ReadAllLines($p)
$n = $all.Count
Write-Output ("engine log lines: " + $n)

# the LAST TWO engine starts: the second-to-last is the poolms capture serve, the
# last is the champion restore (it started right after the capture bench)
$starts = @()
for ($i = 0; $i -lt $n; $i++) { if ($all[$i] -match 'engine started:') { $starts += $i } }
Write-Output ("engine starts: " + ($starts -join ', '))
if ($starts.Count -lt 2) { Write-Output "WARN: fewer than 2 engine starts"; exit 0 }
$capStart = $starts[$starts.Count - 2]
$lastStart = $starts[$starts.Count - 1]
Write-Output ("capture serve at line " + $capStart + ": " + $all[$capStart])
Write-Output ("restore serve at line " + $lastStart + ": " + $all[$lastStart])

# the session lines WITHIN the capture block
$sidx = @()
for ($i = $capStart; $i -lt $lastStart; $i++) { if ($all[$i] -match 'session 0:') { $sidx += $i } }
Write-Output ("session lines after the last start (0-based, absolute): " + ($sidx -join ', '))

$dec = @(); $drafts = @()
foreach ($s in $sidx) {
  if ($all[$s] -match '([0-9]+) generated in ([0-9]+) ms') { $dec += [double]$Matches[2]; $outToks = [double]$Matches[1] }
  if ($all[$s] -match 'drafts accepted ([0-9]+) of ([0-9]+)') { $drafts += [double]$Matches[2] }
  Write-Output ("  session: " + $all[$s])
}
Write-Output ("decode ms per session: " + ($dec -join ', ') + "   drafts-total per session: " + ($drafts -join ', '))

function Sum-Segment([int]$a, [int]$b, [string]$label, [double]$denomMs, [double]$draftsTotal, [double]$outToks) {
  $cnt = 0
  $ms = 0.0; $gu = 0.0; $q = 0.0; $down = 0.0; $exps = 0; $mb = 0.0
  $maxms = 0.0; $minms = 1e9
  $stalls = 0; $stallMs = 0.0
  $hist = @{}
  for ($i = $a; $i -le $b; $i++) {
    $line = $all[$i]
    if ($line -match 'pool-ms: ([0-9.]+) ms \(gu ([0-9.]+) / q ([0-9.]+) / down ([0-9.]+)\), ([0-9]+) experts, ([0-9.]+) MB, ([0-9.]+) GB/s') {
      $cnt++
      $m = [double]$Matches[1]
      $ms += $m
      $gu += [double]$Matches[2]
      $q += [double]$Matches[3]
      $down += [double]$Matches[4]
      $e = [int]$Matches[5]
      $exps += $e
      $mbv = [double]$Matches[6]
      $mb += $mbv
      if ($m -gt $maxms) { $maxms = $m }
      if ($m -lt $minms) { $minms = $m }
      if ($m -gt 10.0) { $stalls++; $stallMs += $m }
      if ($hist.ContainsKey($e)) { $hist[$e]++ } else { $hist[$e] = 1 }
    }
  }
  Write-Output ""
  Write-Output ("== " + $label + " ==")
  Write-Output ("pool-ms lines: " + $cnt)
  if ($cnt -eq 0) { Write-Output "(none)"; return }
  Write-Output ("SUM ms: " + [math]::Round($ms,0) + "  mean/call ms: " + [math]::Round($ms / $cnt,1) + "  (min " + [math]::Round($minms,1) + " max " + [math]::Round($maxms,1) + ")")
  Write-Output ("phases: gu " + [math]::Round($gu,0) + " ms (" + [math]::Round($gu * 100 / $ms,1) + "%) / q " + [math]::Round($q,0) + " ms (" + [math]::Round($q * 100 / $ms,1) + "%) / down " + [math]::Round($down,0) + " ms (" + [math]::Round($down * 100 / $ms,1) + "%)")
  Write-Output ("experts/call mean: " + [math]::Round($exps / $cnt,1) + "   MB/call mean: " + [math]::Round($mb / $cnt,1) + "   SUM MB: " + [math]::Round($mb,0))
  Write-Output ("aggregate GB/s = SUM MB / SUM ms: " + [math]::Round($mb / $ms * 1000, 2))
  Write-Output ("stalls >10 ms: " + $stalls + " calls = " + [math]::Round($stalls * 100 / $cnt,1) + "% of the count, " + [math]::Round($stallMs * 100 / $ms,1) + "% of the SUM (max " + [math]::Round($maxms,1) + " ms)")
  if ($denomMs -gt 0) {
    Write-Output ("pool share of the " + [math]::Round($denomMs,0) + " ms decode: " + [math]::Round($ms * 100 / $denomMs,1) + "%  (stall-free: " + [math]::Round(($ms - $stallMs) * 100 / $denomMs,1) + "%)")
  }
  if ($draftsTotal -gt 0 -and $outToks -gt 0) {
    $steps = $draftsTotal / 2.0
    Write-Output ("call-model check: steps ~ drafts/2 = " + [math]::Round($steps,0) + " -> calls/step " + [math]::Round($cnt / $steps,1) + " (expect ~41 = per-layer) ; tokens/step " + [math]::Round($outToks / $steps,2) + " ; MB/step " + [math]::Round($mb / $steps,0) + " MB")
  }
  $ks = $hist.Keys | Sort-Object
  $hs = ""
  foreach ($k in $ks) { $hs += ("N=" + $k + ":" + $hist[$k] + " ") }
  Write-Output ("experts-per-call histogram: " + $hs)
}

if ($sidx.Count -ge 2) {
  Sum-Segment $capStart ($sidx[0] - 1) "SEGMENT A (load + the warmup round; the 900-s idle sits before its first token)" $dec[0] $drafts[0] $outToks
  Sum-Segment ($sidx[0] + 1) ($sidx[1] - 1) "SEGMENT B (the measured round ONLY)" $dec[1] $drafts[1] $outToks
  if ($sidx.Count -gt 2) { Sum-Segment ($sidx[1] + 1) ($lastStart - 1) "SEGMENT C (after the measured round)" 0 0 0 }
} else {
  Write-Output "WARN: expected 2 session lines in the capture block; got $($sidx.Count)"
  Sum-Segment $capStart ($lastStart - 1) "SEGMENT ALL (no split possible)" 0 0 0
}
