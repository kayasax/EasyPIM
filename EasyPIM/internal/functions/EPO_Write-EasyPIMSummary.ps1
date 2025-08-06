function Write-EasyPIMSummary {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param (
        [Parameter()]
        [PSCustomObject]$CleanupResults,

        [Parameter()]
        [PSCustomObject]$AssignmentResults,

        [Parameter()]
        [hashtable]$PolicyResults,

        [Parameter()]
        [string]$PolicyMode = "delta"
    )

    # Add grand total summary
    Write-Host "`n┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓" -ForegroundColor Green
    Write-Host "┃ OVERALL SUMMARY                                                                ┃" -ForegroundColor Green
    Write-Host "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛" -ForegroundColor Green

    # Assignments section
    Write-Host "┌───────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor White
    Write-Host "│ ASSIGNMENT CREATIONS" -ForegroundColor White
    Write-Host "├───────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor White

    # Handle assignment results - might be null if assignments were skipped
    if ($null -ne $AssignmentResults) {
        Write-Host "│ ✅ Created : $($AssignmentResults.Created)" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped : $($AssignmentResults.Skipped)" -ForegroundColor White
        Write-Host "│ ❌ Failed  : $($AssignmentResults.Failed)" -ForegroundColor White
    } else {
        Write-Host "│ ✅ Created : 0" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped : 0" -ForegroundColor White
        Write-Host "│ ❌ Failed  : 0" -ForegroundColor White
    }
    Write-Host "└───────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor White

    # Policy section
    Write-Host "┌───────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor White
    Write-Host "│ POLICY OPERATIONS" -ForegroundColor White
    Write-Host "├───────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor White

    # Handle policy results - might be null if policies were skipped
    if ($null -ne $PolicyResults -and $null -ne $PolicyResults.Summary) {
        $actionLabel = if ($PolicyMode -eq "validate") { "Validated" } else { "Applied" }
        Write-Host "│ ✅ $actionLabel : $($PolicyResults.Summary.Successful)" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped : $($PolicyResults.Summary.Skipped)" -ForegroundColor White
        Write-Host "│ ❌ Failed  : $($PolicyResults.Summary.Failed)" -ForegroundColor White
        Write-Host "│ 📋 Total   : $($PolicyResults.Summary.TotalProcessed)" -ForegroundColor White
    } else {
        $actionLabel = if ($PolicyMode -eq "validate") { "Validated" } else { "Applied" }
        Write-Host "│ ✅ $actionLabel : 0" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped : 0" -ForegroundColor White
        Write-Host "│ ❌ Failed  : 0" -ForegroundColor White
        Write-Host "│ 📋 Total   : 0" -ForegroundColor White
    }
    Write-Host "└───────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor White

    # Cleanup section
    Write-Host "┌───────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor White
    Write-Host "│ CLEANUP OPERATIONS" -ForegroundColor White
    Write-Host "├───────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor White

    # Handle cleanup results - might be null if cleanup was skipped
    if ($null -ne $CleanupResults) {
        # Support for both property naming conventions
        # First try with "Count" suffix, then without
        $kept = if ($null -ne $CleanupResults.KeptCount) { $CleanupResults.KeptCount }
                elseif ($null -ne $CleanupResults.Kept) { $CleanupResults.Kept }
                else { 0 }

        $removed = if ($null -ne $CleanupResults.RemovedCount) { $CleanupResults.RemovedCount }
                elseif ($null -ne $CleanupResults.Removed) { $CleanupResults.Removed }
                else { 0 }

        $skipped = if ($null -ne $CleanupResults.SkippedCount) { $CleanupResults.SkippedCount }
                elseif ($null -ne $CleanupResults.Skipped) { $CleanupResults.Skipped }
                else { 0 }

        $protected = if ($null -ne $CleanupResults.ProtectedCount) { $CleanupResults.ProtectedCount }
                elseif ($null -ne $CleanupResults.Protected) { $CleanupResults.Protected }
                else { 0 }

        Write-Host "│ ✅ Kept    : $kept" -ForegroundColor White
        Write-Host "│ 🗑️ Removed : $removed" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped : $skipped" -ForegroundColor White
        if ($protected -gt 0) {
            Write-Host "│ 🛡️ Protected: $protected" -ForegroundColor White
        }
    } else {
        Write-Host "│ ✅ Kept    : 0" -ForegroundColor White
        Write-Host "│ 🗑️ Removed : 0" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped : 0" -ForegroundColor White
    }
    Write-Host "└───────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor White
}