# Debug ExpirationRule validation failure
Write-Host "=== Debugging ExpirationRule Validation Failure ===" -ForegroundColor Cyan

# Import EasyPIM and connect
Import-Module .\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psd1 -Force -Global

try {
    # Connect to Microsoft Graph
    Connect-MgGraph -Scopes 'RoleManagement.ReadWrite.Directory','Directory.Read.All','RoleAssignmentSchedule.ReadWrite.Directory','PrivilegedAccess.ReadWrite.AzureAD' -NoWelcome

    # Get the policy for User Administrator
    Write-Host "`n1. Getting User Administrator policy..." -ForegroundColor Yellow
    $policy = Get-PIMEntraRolePolicy -tenantID $env:TENANTID -rolename "User Administrator"

    Write-Host "Policy Values:" -ForegroundColor Green
    Write-Host "  MaximumActiveAssignmentDuration: '$($policy.MaximumActiveAssignmentDuration)'" -ForegroundColor White
    Write-Host "  ActivationDuration: '$($policy.ActivationDuration)'" -ForegroundColor White
    Write-Host "  AllowPermanentActiveAssignment: '$($policy.AllowPermanentActiveAssignment)'" -ForegroundColor White

    # Try to get the role definition ID for User Administrator
    Write-Host "`n2. Getting role definition ID..." -ForegroundColor Yellow
    $roleDefinitions = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'User Administrator'"
    $roleDefId = $roleDefinitions[0].Id
    Write-Host "  Role Definition ID: $roleDefId" -ForegroundColor White

    # Get the RoleManagementPolicy for this role
    Write-Host "`n3. Getting RoleManagementPolicy..." -ForegroundColor Yellow
    $rolePolicy = Get-MgRoleManagementDirectoryRoleAssignmentPolicy -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$roleDefId'"
    $policyId = $rolePolicy[0].Id
    Write-Host "  Policy ID: $policyId" -ForegroundColor White

    # Get the specific ExpirationRule for Admin Assignment
    Write-Host "`n4. Getting Expiration_Admin_Assignment rule..." -ForegroundColor Yellow
    $policyRules = Get-MgRoleManagementDirectoryRoleAssignmentPolicyRule -UnifiedRoleManagementPolicyId $policyId
    $expirationRule = $policyRules | Where-Object { $_.Id -eq "Expiration_Admin_Assignment" }

    if ($expirationRule) {
        Write-Host "Expiration_Admin_Assignment Rule:" -ForegroundColor Green
        Write-Host "  ID: $($expirationRule.Id)" -ForegroundColor White
        Write-Host "  Type: $($expirationRule.AdditionalProperties['@odata.type'])" -ForegroundColor White
        Write-Host "  IsExpirationRequired: $($expirationRule.AdditionalProperties.isExpirationRequired)" -ForegroundColor White
        Write-Host "  MaximumDuration: '$($expirationRule.AdditionalProperties.maximumDuration)'" -ForegroundColor White

        # Check target settings
        $target = $expirationRule.AdditionalProperties.target
        if ($target) {
            Write-Host "  Target.Caller: $($target.caller)" -ForegroundColor White
            Write-Host "  Target.Level: $($target.level)" -ForegroundColor White
        }
    } else {
        Write-Host "ERROR: Could not find Expiration_Admin_Assignment rule!" -ForegroundColor Red
    }

    Write-Host "`n5. Testing various durations..." -ForegroundColor Yellow

    # Test with very short duration
    $testDurations = @("PT30M", "PT1H", "PT2H", "PT4H", "PT8H", "P1D")

    foreach ($testDuration in $testDurations) {
        Write-Host "  Testing duration: $testDuration" -ForegroundColor Cyan -NoNewline

        try {
            $result = New-PIMEntraRoleActiveAssignment -tenantID $env:TENANTID -principalID $env:TESTUSERID -rolename "User Administrator" -duration $testDuration -justification "Test assignment - duration $testDuration" -WhatIf
            Write-Host " -> SUCCESS (WhatIf)" -ForegroundColor Green
        } catch {
            if ($_.Exception.Message -like "*ExpirationRule*") {
                Write-Host " -> FAILED: ExpirationRule" -ForegroundColor Red
            } elseif ($_.Exception.Message -like "*exceeds policy*") {
                Write-Host " -> FAILED: Exceeds policy limit" -ForegroundColor Orange
            } else {
                Write-Host " -> FAILED: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}
