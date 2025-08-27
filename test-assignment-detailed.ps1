# Quick test of the assignment function to see detailed error
Import-Module .\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psm1 -Force -Global

try {
    Write-Host "Testing New-PIMEntraRoleActiveAssignment with detailed output..." -ForegroundColor Cyan

    $result = New-PIMEntraRoleActiveAssignment -TenantID $env:TENANTID -RoleName 'User Administrator' -PrincipalID '8b0995d0-4c07-4814-98c8-550dc0af62cf' -Duration 'PT1H' -Justification 'Testing assignment function' -DebugGraphPayload -ErrorAction Stop

    Write-Host "SUCCESS! Assignment created:" -ForegroundColor Green
    Write-Host "Status: $($result.status)" -ForegroundColor White
    Write-Host "Action: $($result.action)" -ForegroundColor White
    Write-Host "ID: $($result.id)" -ForegroundColor White

} catch {
    Write-Host "ERROR DETAILS:" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Yellow
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Yellow

    if ($_.Exception.InnerException) {
        Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Yellow
    }

    # Try to get more details from the error record
    if ($_.ErrorDetails) {
        Write-Host "Error Details: $($_.ErrorDetails)" -ForegroundColor Yellow
    }

    # Show the full error record for troubleshooting
    Write-Host "`nFull Error Record:" -ForegroundColor Magenta
    $_ | Format-List -Force
}
