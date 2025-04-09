function Write-EasyPIMSummary {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param (
        [Parameter()]
        [PSCustomObject]$CleanupResults,
        
        [Parameter()]
        [PSCustomObject]$AssignmentResults
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
    
    # Cleanup section
    Write-Host "┌───────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor White
    Write-Host "│ CLEANUP OPERATIONS" -ForegroundColor White
    Write-Host "├───────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor White
    
    # Handle cleanup results - might be null if cleanup was skipped
    if ($null -ne $CleanupResults) {
        Write-Host "│ ✅ Kept    : $($CleanupResults.Kept)" -ForegroundColor White
        Write-Host "│ 🗑️ Removed : $($CleanupResults.Removed)" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped : $($CleanupResults.Skipped)" -ForegroundColor White
        if ($CleanupResults.Protected -gt 0) {
            Write-Host "│ 🛡️ Protected: $($CleanupResults.Protected)" -ForegroundColor White
        }
    } else {
        Write-Host "│ ✅ Kept    : 0" -ForegroundColor White
        Write-Host "│ 🗑️ Removed : 0" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped : 0" -ForegroundColor White
    }
    Write-Host "└───────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor White
}