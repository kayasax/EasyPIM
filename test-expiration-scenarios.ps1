# Comprehensive ExpirationRule validation test
Import-Module .\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psd1 -Force -Global

# Test different scenarios to identify the root cause
function Test-PIMRequest {
    param(
        [string]$TestName,
        [hashtable]$RequestBody,
        [bool]$ExpectSuccess = $false
    )

    Write-Host "`n=== Testing: $TestName ===" -ForegroundColor Yellow

    try {
        $jsonBody = $RequestBody | ConvertTo-Json -Depth 10
        Write-Host "Request body:" -ForegroundColor Cyan
        Write-Host $jsonBody -ForegroundColor White

        $endpoint = "roleManagement/directory/roleAssignmentScheduleRequests/"
        $result = invoke-graph -Endpoint $endpoint -Method "POST" -body $jsonBody

        if ($ExpectSuccess) {
            Write-Host "✅ SUCCESS: $TestName" -ForegroundColor Green
        } else {
            Write-Host "⚠️ UNEXPECTED SUCCESS: $TestName" -ForegroundColor Yellow
        }
        return $result

    } catch {
        if ($ExpectSuccess) {
            Write-Host "❌ FAILED: $TestName" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        } else {
            Write-Host "📋 EXPECTED FAILURE: $TestName" -ForegroundColor Magenta
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $null
    }
}

try {
    Connect-MgGraph -Scopes 'RoleManagement.ReadWrite.Directory','Directory.Read.All','RoleAssignmentSchedule.ReadWrite.Directory' -NoWelcome

    # Get User Administrator role details
    $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'User Administrator'"
    $roleDefId = $roleDefinition[0].Id
    Write-Host "User Administrator Role ID: $roleDefId" -ForegroundColor Green

    # Get a test user (current user)
    $currentUser = Get-MgContext
    $testUserId = (Get-MgUser -Filter "userPrincipalName eq '$($currentUser.Account)'").Id
    Write-Host "Test User ID: $testUserId" -ForegroundColor Green

    # Base request template
    $baseRequest = @{
        action = "adminAssign"
        justification = "Testing ExpirationRule validation"
        roleDefinitionId = $roleDefId
        directoryScopeId = "/"
        principalId = $testUserId
        scheduleInfo = @{
            startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
    }

    # Test 1: Request with PT1H duration (current failing scenario)
    $test1 = $baseRequest.Clone()
    $test1.scheduleInfo.expiration = @{
        type = "AfterDuration"
        duration = "PT1H"
    }
    $test1.ticketInfo = @{
        ticketNumber = "EasyPIM"
        ticketSystem = "EasyPIM"
    }
    Test-PIMRequest -TestName "Current failing scenario (PT1H with ticketInfo)" -RequestBody $test1

    # Test 2: Request without ticketInfo
    $test2 = $baseRequest.Clone()
    $test2.scheduleInfo.expiration = @{
        type = "AfterDuration"
        duration = "PT1H"
    }
    Test-PIMRequest -TestName "PT1H without ticketInfo" -RequestBody $test2

    # Test 3: Request with PT30M duration
    $test3 = $baseRequest.Clone()
    $test3.scheduleInfo.expiration = @{
        type = "AfterDuration"
        duration = "PT30M"
    }
    $test3.ticketInfo = @{
        ticketNumber = "EasyPIM"
        ticketSystem = "EasyPIM"
    }
    Test-PIMRequest -TestName "PT30M with ticketInfo" -RequestBody $test3

    # Test 4: Permanent assignment (NoExpiration)
    $test4 = $baseRequest.Clone()
    $test4.scheduleInfo.expiration = @{
        type = "NoExpiration"
    }
    $test4.ticketInfo = @{
        ticketNumber = "EasyPIM"
        ticketSystem = "EasyPIM"
    }
    Test-PIMRequest -TestName "Permanent assignment (NoExpiration)" -RequestBody $test4

    # Test 5: IsValidationOnly to check policy compliance
    $test5 = $baseRequest.Clone()
    $test5.scheduleInfo.expiration = @{
        type = "AfterDuration"
        duration = "PT1H"
    }
    $test5.ticketInfo = @{
        ticketNumber = "EasyPIM"
        ticketSystem = "EasyPIM"
    }
    $test5.isValidationOnly = $true
    Test-PIMRequest -TestName "Validation only test (PT1H)" -RequestBody $test5

} catch {
    Write-Error "Test script error: $($_.Exception.Message)"
}
