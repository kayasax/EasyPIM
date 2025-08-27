# Generate the exact JSON structure to debug syntax issues
Import-Module .\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psm1 -Force -Global

# Simulate the exact values used in the function
$tenantID = $env:TENANTID
$rolename = 'User Administrator'
$principalID = '8b0995d0-4c07-4814-98c8-550dc0af62cf'
$justification = 'Debug JSON test'
$startDateTime = Get-Date (Get-Date).ToUniversalTime() -f "yyyy-MM-ddTHH:mm:ssZ"
$duration = 'PT1H'

# Get the role configuration
$config = Get-PIMEntraRolePolicy -tenantID $tenantID -rolename $rolename

# Simulate the exact JSON construction from the function
$expirationJson = '"expiration": { "type": "AfterDuration", "duration": "' + $duration + '" }'

# The problematic ticketInfoJson construction
$ticketInfoJson = '"ticketInfo": { "ticketNumber": "EasyPIM-' + (Get-Date -Format "yyyyMMdd-HHmmss") + '", "ticketSystem": "EasyPIM", "ticketSubmitterIdentityId": "' + (Get-MgContext).Account + '", "ticketApproverIdentityId": "' + (Get-MgContext).Account + '" }'

Write-Host "=== JSON Component Analysis ===" -ForegroundColor Cyan
Write-Host "Expiration JSON:" -ForegroundColor Yellow
Write-Host "  $expirationJson" -ForegroundColor White

Write-Host "`nTicket Info JSON:" -ForegroundColor Yellow
Write-Host "  $ticketInfoJson" -ForegroundColor White

# Construct the full body exactly as the function does
$body = '
{
    "action": "adminAssign",
    "justification": "'+ $justification + '",
    "roleDefinitionId": "'+ $config.roleID + '",
    "directoryScopeId": "/",
    "principalId": "'+ $principalID + '",
    "scheduleInfo": {
        "startDateTime": "'+ $startDateTime + '",
        ' + $expirationJson + '
    },
    ' + $ticketInfoJson + '
}

'

Write-Host "`n=== Complete JSON Body ===" -ForegroundColor Cyan
Write-Host $body -ForegroundColor White

Write-Host "`n=== JSON Validation Test ===" -ForegroundColor Cyan
try {
    $parsed = $body | ConvertFrom-Json
    Write-Host "✅ JSON is syntactically valid" -ForegroundColor Green

    Write-Host "`n📊 Parsed Properties:" -ForegroundColor Yellow
    $parsed.PSObject.Properties | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor White
    }

    if ($parsed.ticketInfo) {
        Write-Host "`n🎫 Ticket Info Details:" -ForegroundColor Yellow
        $parsed.ticketInfo.PSObject.Properties | ForEach-Object {
            Write-Host "    $($_.Name): $($_.Value)" -ForegroundColor White
        }
    }

} catch {
    Write-Host "❌ JSON SYNTAX ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "This is the root cause of InvalidRoleAssignmentRequest" -ForegroundColor Yellow
}
