$ErrorActionPreference = "SilentlyContinue"
Get-ChildItem "research\trials" -Recurse -Filter *.json | ForEach-Object {
  $rel = $_.FullName.Replace((Get-Item "research\trials").FullName + "\", "")
  $j = Get-Content $_.FullName -Raw | ConvertFrom-Json
  Write-Output ($rel + " -> decode_tps " + $j.decode_tps + " prefill " + $j.prefill_tps + " peak " + $j.peak_gib)
}
