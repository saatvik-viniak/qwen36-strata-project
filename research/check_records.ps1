Get-Content research\hillclimb\ledger.jsonl -Tail 2
Write-Output '=== SUGGESTIONS tail ==='
Get-Content SUGGESTIONS.MD -Tail 30
Write-Output '=== git log ==='
git log --oneline -4
