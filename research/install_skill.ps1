# Install the inference-optimisation skill into the OpenCode user skills dir
$src = 'C:\Users\Admin\Auto-research-agent\Runtime\projects\saatvik-viniak\qwen36-strata-project\research\inference-optimisation-skill\skills\inference-optimisation'
$dst = 'C:\Users\Admin\.config\opencode\skills\inference-optimisation'
if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force
Write-Output 'INSTALLED:'
Get-ChildItem $dst -Recurse | ForEach-Object { Write-Output $_.FullName.Replace($dst, '') }
