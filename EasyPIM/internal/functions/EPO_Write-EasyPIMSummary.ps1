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
    Write-Host "│ ✅ Created : $($AssignmentResults.Created)" -ForegroundColor White
    Write-Host "│ ⏭️ Skipped : $($AssignmentResults.Skipped)" -ForegroundColor White
    Write-Host "│ ❌ Failed  : $($AssignmentResults.Failed)" -ForegroundColor White
    Write-Host "└───────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor White
    
    # Cleanup section
    Write-Host "┌───────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor White
    Write-Host "│ CLEANUP OPERATIONS" -ForegroundColor White
    Write-Host "├───────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor White
    Write-Host "│ ✅ Kept    : $($CleanupResults.Kept)" -ForegroundColor White
    Write-Host "│ 🗑️ Removed : $($CleanupResults.Removed)" -ForegroundColor White
    Write-Host "│ ⏭️ Skipped : $($CleanupResults.Skipped)" -ForegroundColor White
    if ($CleanupResults.Protected -gt 0) {
        Write-Host "│ 🛡️ Protected: $($CleanupResults.Protected)" -ForegroundColor White
    }
    Write-Host "└───────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor White
}