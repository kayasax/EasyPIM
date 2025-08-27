# Simple test script to check if the type parameter works
try {
    . ".\EasyPIM\functions\Get-PIMGroupEligibleAssignment.ps1"

    $params = (Get-Command Get-PIMGroupEligibleAssignment).Parameters

    Write-Host "Parameters found:"
    $params.Keys | Sort-Object | ForEach-Object { Write-Host "  - $_" }

    if ($params.ContainsKey('type')) {
        Write-Host "✅ type parameter found!"
    } else {
        Write-Host "❌ type parameter missing!"
    }

} catch {
    Write-Host "❌ Error loading function: $($_.Exception.Message)"
}
