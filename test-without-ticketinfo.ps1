# Test assignment WITHOUT ticketInfo to see if that's the issue
Import-Module .\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psm1 -Force -Global

Write-Host "=== Testing assignment WITHOUT ticketInfo ===" -ForegroundColor Cyan

# Connect to Graph
Connect-MgGraph -Scopes 'RoleManagement.ReadWrite.Directory','Directory.Read.All','RoleAssignmentSchedule.ReadWrite.Directory' -NoWelcome

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
    $headers = @{
        'Authorization' = "Bearer $((Get-MgContext).AuthToken)"
        'Content-Type' = 'application/json'
    }

    # Use Invoke-RestMethod for better error details
    $response = Invoke-RestMethod -Uri $uri -Method POST -Body $jsonBody -Headers $headers

    Write-Host "✅ SUCCESS: Assignment created without ticketInfo!" -ForegroundColor Green
    Write-Host "Status: $($response.status)" -ForegroundColor White
    Write-Host "ID: $($response.id)" -ForegroundColor White

} catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red

    if ($_.Exception.Response) {
        $errorStream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorStream)
        $errorBody = $reader.ReadToEnd()
        Write-Host "Error details: $errorBody" -ForegroundColor Yellow
    }
}
