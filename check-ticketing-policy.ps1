# Check if ticketing is required for User Administrator role
Import-Module .\EasyPIM\EasyPIM.psd1 -Force -Global

Write-Host "=== Checking User Administrator Role Policy ===" -ForegroundColor Cyan

# Check existing Graph context
$mgContext = Get-MgContext
if ($mgContext) {
    Write-Host "✅ Already connected to Graph" -ForegroundColor Green
} else {
    Write-Host "⚠️ Connecting to Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes 'RoleManagement.ReadWrite.Directory','Directory.Read.All','RoleAssignmentSchedule.ReadWrite.Directory' -NoWelcome
}

# Get User Administrator role
$roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'User Administrator'"
$roleDefId = $roleDefinition[0].Id
Write-Host "Role ID: $roleDefId" -ForegroundColor Green

# Get role settings policy
try {
    $roleSettingsPolicy = Get-MgPolicyRoleManagementPolicyAssignment -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$roleDefId'"

    if ($roleSettingsPolicy) {
        $policyId = $roleSettingsPolicy[0].PolicyId
        Write-Host "Policy ID: $policyId" -ForegroundColor Green

        # Get the actual policy rules
        $policy = Get-MgPolicyRoleManagementPolicy -UnifiedRoleManagementPolicyId $policyId -ExpandProperty Rules

        Write-Host "`n=== Policy Rules ===" -ForegroundColor Cyan
        foreach ($rule in $policy.Rules) {
            if ($rule.Id -like "*TicketingRule*") {
                Write-Host "📝 Ticketing Rule Found:" -ForegroundColor Yellow
                Write-Host "  ID: $($rule.Id)" -ForegroundColor White
                Write-Host "  Target: $($rule.Target.Operations -join ', ')" -ForegroundColor White
                Write-Host "  IsEnabled: $($rule.AdditionalProperties.isTicketingRequired)" -ForegroundColor White
            }

            if ($rule.Id -like "*ExpirationRule*" -and $rule.Target.Operations -contains "All") {
                Write-Host "⏰ Expiration Rule Found:" -ForegroundColor Yellow
                Write-Host "  ID: $($rule.Id)" -ForegroundColor White
                Write-Host "  Target: $($rule.Target.Operations -join ', ')" -ForegroundColor White
                Write-Host "  MaxDuration: $($rule.AdditionalProperties.maximumDuration)" -ForegroundColor White
            }
        }
    } else {
        Write-Host "❌ No policy assignment found for User Administrator role" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error getting policy: $($_.Exception.Message)" -ForegroundColor Red
}
