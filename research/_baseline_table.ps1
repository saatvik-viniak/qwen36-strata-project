# Tabulate the Q5 champion baseline (3 passes) vs the Q4_K_S baseline (1 pass).
$dirs = @(
  @{ name='Q5 pass1'; path='research\baseline\pass1' },
  @{ name='Q5 pass2'; path='research\baseline\pass2' },
  @{ name='Q5 pass3'; path='research\baseline\pass3' },
  @{ name='Q4KS pass'; path='research\q4ks_baseline' }
)
$cells = @('empty','ctx32k','ctx128k')
foreach ($d in $dirs) {
  Write-Output ("=== {0} ===" -f $d.name)
  foreach ($c in $cells) {
    $p = Join-Path $d.path ($c + '.json')
    if (-not (Test-Path $p)) { Write-Output ("  {0}: MISSING" -f $c); continue }
    $j = Get-Content $p -Raw | ConvertFrom-Json
    $req = $j.prompt_tokens_requested
    $act = $j.prompt_tokens_actual
    $out = $j.output_tokens
    Write-Output ("  {0}: decode={1} tok/s  prefill={2} tok/s  ttft={3} ms  req={4} act={5} out={6} peak={7} GiB" -f $c, [math]::Round($j.decode_tps,3), [math]::Round($j.prefill_tps,1), [math]::Round($j.ttft_ms,0), $req, $act, $out, [math]::Round($j.peak_gib,2))
  }
}
# the 2.00x targets per cell from the mission protocol: median of the 3 passes? print medians
Write-Output "=== Q5 medians (3 passes) ==="
foreach ($c in $cells) {
  $vals = @()
  foreach ($d in @('pass1','pass2','pass3')) {
    $p = Join-Path 'research\baseline' ($d + '\{0}.json' -f $c)
    if (Test-Path $p) { $j = Get-Content $p -Raw | ConvertFrom-Json; $vals += [double]$j.decode_tps }
  }
  $vals = $vals | Sort-Object
  if ($vals.Count -gt 0) {
    $med = $vals[([math]::Floor(($vals.Count-1)/2))]
    Write-Output ("  {0}: median decode = {1} tok/s  (n={2})" -f $c, [math]::Round($med,3), $vals.Count)
  }
}
