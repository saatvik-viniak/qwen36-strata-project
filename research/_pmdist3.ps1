# _pmdist3.ps1 — the per-call ms distribution + the stall share (the primary
# agent's _pmdist/_pmdist2 analysis, computed from the canonical engine.log slice)
$Error.Clear()
$slice = [System.IO.File]::ReadAllLines("$PSScriptRoot\poolms\engine.log")
$n = $slice.Count
$sidx = @()
for ($i = 0; $i -lt $n; $i++) { if ($slice[$i] -match 'session 0:') { $sidx += $i } }

# segment B = between the session lines (the measured round)
$meas = @()
for ($i = $sidx[0] + 1; $i -le $sidx[1] - 1; $i++) {
  if ($slice[$i] -match 'pool-ms: ([0-9.]+) ms \(gu ([0-9.]+) / q ([0-9.]+) / down ([0-9.]+)\), ([0-9]+) experts, ([0-9.]+) MB') {
    $meas += @{ ms = [double]$Matches[1]; gu = [double]$Matches[2]; q = [double]$Matches[3]; down = [double]$Matches[4]; e = [int]$Matches[5]; mb = [double]$Matches[6] }
  }
}
$pre = @()
for ($i = 0; $i -le $sidx[0] - 1; $i++) {
  if ($slice[$i] -match 'pool-ms: ([0-9.]+) ms') { $pre += [double]$Matches[1] }
}

$b = @{ l1 = 0; l2 = 0; l4 = 0; l8 = 0; l16 = 0; l32 = 0; l64 = 0 }
$bigN = 0; $bigMs = 0.0; $sumAll = 0.0
$smallN = 0; $smallMs = 0.0; $smallMb = 0.0
$sumMb = 0.0
foreach ($p in $meas) {
  $m = $p.ms; $sumAll += $m; $sumMb += $p.mb
  if ($m -lt 1) { $b.l1++ } elseif ($m -lt 2) { $b.l2++ } elseif ($m -lt 4) { $b.l4++ } elseif ($m -lt 8) { $b.l8++ } elseif ($m -lt 16) { $b.l16++ } elseif ($m -lt 32) { $b.l32++ } else { $b.l64++ }
  if ($m -gt 10) { $bigN++; $bigMs += $m } else { $smallN++; $smallMs += $m; $smallMb += $p.mb }
}
Write-Output "== the measured round: per-call ms distribution =="
Write-Output ("calls " + $meas.Count + "; SUM " + [math]::Round($sumAll,0) + " ms")
Write-Output ("buckets <1ms:" + $b.l1 + "  1-2:" + $b.l2 + "  2-4:" + $b.l4 + "  4-8:" + $b.l8 + "  8-16:" + $b.l16 + "  16-32:" + $b.l32 + "  32+:" + $b.l64)
Write-Output ("calls >10ms: " + $bigN + " summing " + [math]::Round($bigMs,0) + " ms (" + [math]::Round($bigMs * 100 / $sumAll,1) + "% of SUM)")
Write-Output ("calls <=10ms: " + $smallN + " of " + $meas.Count + "; SUM " + [math]::Round($smallMs,0) + " ms -> share vs decode 26853 = " + [math]::Round($smallMs * 100 / 26853,1) + "%")
Write-Output ("stall-free aggregate GB/s: " + [math]::Round($smallMb / $smallMs * 1000,2) + "  (all-calls aggregate: " + [math]::Round($sumMb / $sumAll * 1000,2) + "; ceiling 28)")

$preBigN = 0; $preBigMs = 0.0; $preSum = 0.0
foreach ($m in $pre) { $preSum += $m; if ($m -gt 10) { $preBigN++; $preBigMs += $m } }
Write-Output ""
Write-Output "== the warmup region (load + warmup round): the stall share =="
Write-Output ("calls " + $pre.Count + "; SUM " + [math]::Round($preSum,0) + " ms; >10ms: " + $preBigN + " calls summing " + [math]::Round($preBigMs,0) + " ms (" + [math]::Round($preBigMs * 100 / $preSum,1) + "%)")

# the top-10 slowest calls of the measured round with their phase split
Write-Output ""
Write-Output "== the measured round's 10 slowest calls =="
$sorted = $meas | Sort-Object { $_.ms } -Descending | Select-Object -First 10
foreach ($p in $sorted) {
  Write-Output ("  " + [math]::Round($p.ms,1) + " ms (gu " + [math]::Round($p.gu,1) + " / q " + [math]::Round($p.q,1) + " / down " + [math]::Round($p.down,1) + "), " + $p.e + " experts, " + [math]::Round($p.mb,1) + " MB")
}
