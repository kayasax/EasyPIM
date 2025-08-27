# Simple JSON structure test
Write-Host "=== Testing JSON Structure Components ===" -ForegroundColor Cyan

# Test the basic components
$duration = 'PT1H'
$expirationJson = '"expiration": { "type": "AfterDuration", "duration": "' + $duration + '" }'

Write-Host "Expiration JSON component:" -ForegroundColor Yellow
Write-Host $expirationJson -ForegroundColor White

# Test ticketInfo - this is likely where the issue is
$ticketNumber = "EasyPIM-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$userAccount = "test@domain.com"  # Simulate account

$ticketInfoJson = '"ticketInfo": { "ticketNumber": "' + $ticketNumber + '", "ticketSystem": "EasyPIM", "ticketSubmitterIdentityId": "' + $userAccount + '", "ticketApproverIdentityId": "' + $userAccount + '" }'

Write-Host "`nTicket Info JSON component:" -ForegroundColor Yellow
Write-Host $ticketInfoJson -ForegroundColor White

# Test the complete structure
$testBody = '{
    "action": "adminAssign",
    "justification": "Test justification",
    "roleDefinitionId": "test-role-id",
    "directoryScopeId": "/",
    "principalId": "test-principal-id",
    "scheduleInfo": {
        "startDateTime": "2025-08-27T12:00:00Z",
        ' + $expirationJson + '
    },
    ' + $ticketInfoJson + '
}'

Write-Host "`n=== Complete Test JSON ===" -ForegroundColor Cyan
Write-Host $testBody -ForegroundColor White

Write-Host "`n=== Validation Test ===" -ForegroundColor Cyan
try {
    $parsed = $testBody | ConvertFrom-Json
    Write-Host "✅ JSON is valid!" -ForegroundColor Green
} catch {
    Write-Host "❌ JSON Error: $($_.Exception.Message)" -ForegroundColor Red

    # Let's try to identify the specific issue
    Write-Host "`nLet's test each component separately..." -ForegroundColor Yellow

    # Test basic structure without ticketInfo
    $basicJson = '{
        "action": "adminAssign",
        "justification": "Test",
        "roleDefinitionId": "test-role-id",
        "directoryScopeId": "/",
        "principalId": "test-principal-id",
        "scheduleInfo": {
            "startDateTime": "2025-08-27T12:00:00Z",
            ' + $expirationJson + '
        }
    }'

    try {
        $basicJson | ConvertFrom-Json | Out-Null
        Write-Host "✅ Basic structure is valid" -ForegroundColor Green
        Write-Host "❌ Issue is in ticketInfo structure" -ForegroundColor Red
    } catch {
        Write-Host "❌ Issue is in basic structure: $($_.Exception.Message)" -ForegroundColor Red
    }
}
