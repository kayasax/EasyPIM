# Test assignment WITHOUT ticketInfo using proper authentication context
Import-Module .\EasyPIM\EasyPIM.psd1 -Force -Global

Write-Host "=== Testing assignment WITHOUT ticketInfo ===" -ForegroundColor Cyan

# Check existing Graph context
$mgContext = Get-MgContext
if ($mgContext) {
    Write-Host "✅ Already connected to Graph" -ForegroundColor Green
} else {
    Write-Host "⚠️ Connecting to Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes 'RoleManagement.ReadWrite.Directory','Directory.Read.All','RoleAssignmentSchedule.ReadWrite.Directory' -NoWelcome
}

# Get User Administrator role details
$roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'User Administrator'"
$roleDefId = $roleDefinition[0].Id
Write-Host "Role ID: $roleDefId" -ForegroundColor Green

# Test direct Graph API call WITHOUT ticketInfo
$testAssignment = @{
    action = "adminAssign"
    justification = "Testing without ticketInfo"
    roleDefinitionId = $roleDefId
    directoryScopeId = "/"
    principalId = "8b0995d0-4c07-4814-98c8-550dc0af62cf"
    scheduleInfo = @{
        startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        expiration = @{
            type = "AfterDuration"
            duration = "PT1H"
        }
    }
}

$jsonBody = $testAssignment | ConvertTo-Json -Depth 10
Write-Host "JSON without ticketInfo:" -ForegroundColor Yellow
Write-Host $jsonBody -ForegroundColor White

try {
    Write-Host "`nTesting Graph API call..." -ForegroundColor Cyan
    $uri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleRequests/"

    # Use Invoke-MgGraphRequest for proper authentication
    $response = Invoke-MgGraphRequest -Uri $uri -Method POST -Body $jsonBody

    Write-Host "✅ SUCCESS: Assignment created without ticketInfo!" -ForegroundColor Green
    Write-Host "Status: $($response.status)" -ForegroundColor White
    Write-Host "ID: $($response.id)" -ForegroundColor White

} catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red

    if ($_.ErrorDetails) {
        Write-Host "Error details: $($_.ErrorDetails)" -ForegroundColor Yellow
    }

    if ($_.Exception.Response) {
        Write-Host "Response status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    }
}
