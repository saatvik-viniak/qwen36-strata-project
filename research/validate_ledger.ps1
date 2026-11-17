$ErrorActionPreference = "Stop"
$lines = Get-Content research\hillclimb\ledger.jsonl | Where-Object { $_.Trim() -ne "" }
$i = 0
foreach ($l in $lines) {
  $i++
  $null = $l | ConvertFrom-Json
}
Write-Output "ledger OK: $i entries parse"
