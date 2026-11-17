# _pm_analyze.ps1 — Lever A's capture analysis per the pre-registered protocol
# (session-line split: the measured round's pool-ms lines are BETWEEN the two
# session lines; SUM/2 is NOT used — it was shown to overstate ~1.75x).
$Error.Clear()
$slice = [System.IO.File]::ReadAllLines("$PSScriptRoot\poolms\engine.log")
$n = $slice.Count
Write-Output ("slice lines: " + $n)

$sidx = @()
for ($i = 0; $i -lt $n; $i++) { if ($slice[$i] -match 'session 0:') { $sidx += $i } }
Write-Output ("session lines at (0-based): " + ($sidx -join ', '))
if ($sidx.Count -ne 2) { Write-Output "WARN: expected exactly 2 session lines" }

$dec = @()
foreach ($s in $sidx) {
  if ($slice[$s] -match '512 generated in ([0-9]+) ms') { $dec += [double]$Matches[1] }
}
Write-Output ("decode ms per round: " + ($dec -join ', '))

function Sum-Segment([int]$a, [int]$b, [string]$label, [double]$denomMs, [double]$stepsHint) {
  $cnt = 0
  $ms = 0.0; $gu = 0.0; $q = 0.0; $down = 0.0; $exps = 0; $mb = 0.0
  $maxms = 0.0; $minms = 1e9
  $hist = @{}
  for ($i = $a; $i -le $b; $i++) {
    $line = $slice[$i]
    if ($line -match 'pool-ms: ([0-9.]+) ms \(gu ([0-9.]+) / q ([0-9.]+) / down ([0-9.]+)\), ([0-9]+) experts, ([0-9.]+) MB') {
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
      if ($hist.ContainsKey($e)) { $hist[$e]++ } else { $hist[$e] = 1 }
    }
  }
  Write-Output ""
  Write-Output ("== " + $label + " ==")
  Write-Output ("pool-ms lines: " + $cnt)
  if ($cnt -eq 0) { Write-Output "(none)"; return }
  Write-Output ("SUM ms: " + [math]::Round($ms,0) + "  mean/call ms: " + [math]::Round($ms / $cnt,1) + "  (min " + [math]::Round($minms,1) + " max " + [math]::Round($maxms,1) + ")")
  Write-Output ("phases: gu " + [math]::Round($gu,0) + " ms (" + [math]::Round($gu * 100 / $ms,1) + "%) / q " + [math]::Round($q,0) + " ms (" + [math]::Round($q * 100 / $ms,1) + "%) / down " + [math]::Round($down,0) + " ms (" + [math]::Round($down * 100 / $ms,1) + "%)")
  Write-Output ("experts/call mean: " + [math]::Round($exps / $cnt,1) + "   MB/call mean: " + [math]::Round($mb / $cnt,1))
  Write-Output ("SUM MB: " + [math]::Round($mb,0))
  Write-Output ("aggregate GB/s = SUM MB / SUM ms: " + [math]::Round($mb / $ms * 1000, 2))
  if ($denomMs -gt 0) {
    Write-Output ("pool share of the " + [math]::Round($denomMs,0) + " ms decode: " + [math]::Round($ms * 100 / $denomMs,1) + "%")
  }
  if ($stepsHint -gt 0) {
    Write-Output ("MB per step (~" + [math]::Round($stepsHint,0) + " steps): " + [math]::Round($mb / $stepsHint,0) + "  (bracket 660 MB - 1.98 GB/step)")
    Write-Output ("lines per step: " + [math]::Round($cnt / $stepsHint,1) + "  (call-model check: ~41 = per-layer, ~1 = per-step batch)")
  }
  $ks = $hist.Keys | Sort-Object
  $hs = ""
  foreach ($k in $ks) { $hs += ("N=" + $k + ":" + $hist[$k] + " ") }
  Write-Output ("experts-per-call histogram: " + $hs)
}

if ($sidx.Count -eq 2) {
  # steps per round: drafts accepted 308 of 410 -> ~410 verify steps per round
  Sum-Segment 0 ($sidx[0] - 1) "SEGMENT A (load + gate-warmup + the warmup round)" $dec[0] 410
  Sum-Segment ($sidx[0] + 1) ($sidx[1] - 1) "SEGMENT B (the measured round ONLY)" $dec[1] 410
  Sum-Segment ($sidx[1] + 1) ($n - 1) "SEGMENT C (after the measured round)" 0 0
}
