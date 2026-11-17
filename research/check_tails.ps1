$ErrorActionPreference = "SilentlyContinue"
Write-Output "== handoff line count + tail =="
(Get-Content RESEARCH_HANDOFF.md).Count
Get-Content RESEARCH_HANDOFF.md -Tail 22
Write-Output "== notebook line count + tail =="
(Get-Content research\NOTEBOOK.md).Count
Get-Content research\NOTEBOOK.md -Tail 8
