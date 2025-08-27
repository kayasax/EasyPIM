# Simple policy check for User Administrator
try {
    # Import module
    Import-Module .\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psd1 -Force -Global

    # Connect with minimal scope
    Connect-MgGraph -Scopes 'RoleManagement.Read.Directory' -NoWelcome

    Write-Host "Connected to Microsoft Graph" -ForegroundColor Green

    # Get User Administrator role definition
    $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'User Administrator'"
    $roleDefId = $roleDefinition[0].Id
    Write-Host "User Administrator Role ID: $roleDefId" -ForegroundColor Cyan

    # Get the policy for this role
    $rolePolicy = Get-MgRoleManagementDirectoryRoleAssignmentPolicy -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$roleDefId'"
    Write-Host "Policy ID: $($rolePolicy.Id)" -ForegroundColor Cyan

    # Get all policy rules
    $policyRules = Get-MgRoleManagementDirectoryRoleAssignmentPolicyRule -UnifiedRoleManagementPolicyId $rolePolicy.Id

    Write-Host "`n=== Policy Rules Analysis ===" -ForegroundColor Yellow

    # Check Enablement_Admin_Assignment rule
    $enablementAdminRule = $policyRules | Where-Object { $_.Id -eq "Enablement_Admin_Assignment" }
    if ($enablementAdminRule) {
        Write-Host "`n🔍 Enablement_Admin_Assignment:" -ForegroundColor Green
        $enabledRules = $enablementAdminRule.AdditionalProperties.enabledRules
        Write-Host "  Enabled Rules: $($enabledRules -join ', ')" -ForegroundColor White

        if ($enabledRules -contains "Justification") {
            Write-Host "  ✅ Justification required" -ForegroundColor Yellow
        }
        if ($enabledRules -contains "Ticketing") {
            Write-Host "  🎫 Ticketing required" -ForegroundColor Yellow
        }
        if ($enabledRules -contains "MultiFactorAuthentication") {
            Write-Host "  🔐 MFA required" -ForegroundColor Yellow
        }
    }

    # Check Expiration_Admin_Assignment rule
    $expirationAdminRule = $policyRules | Where-Object { $_.Id -eq "Expiration_Admin_Assignment" }
    if ($expirationAdminRule) {
        Write-Host "`n⏰ Expiration_Admin_Assignment:" -ForegroundColor Green
        Write-Host "  Maximum Duration: '$($expirationAdminRule.AdditionalProperties.maximumDuration)'" -ForegroundColor White
        Write-Host "  Is Expiration Required: $($expirationAdminRule.AdditionalProperties.isExpirationRequired)" -ForegroundColor White
    }

    # Check if there's a different issue - like approval requirements
    $approvalRule = $policyRules | Where-Object { $_.Id -eq "Approval_Admin_Assignment" }
    if ($approvalRule) {
        Write-Host "`n📋 Approval_Admin_Assignment:" -ForegroundColor Green
        $settings = $approvalRule.AdditionalProperties.setting
        if ($settings -and $settings.isApprovalRequired) {
            Write-Host "  ⚠️  Approval IS required for admin assignments!" -ForegroundColor Red
            Write-Host "  This could be why the request fails - approval workflow needed" -ForegroundColor Red
        } else {
            Write-Host "  ✅ No approval required" -ForegroundColor Green
        }
    }

    Write-Host "`n=== Summary ===" -ForegroundColor Yellow
    Write-Host "Based on policy analysis, the ExpirationRule failure might be due to:" -ForegroundColor White
    Write-Host "1. Duration exceeding policy limits" -ForegroundColor White
    Write-Host "2. Missing required enablement rules (justification, ticketing, MFA)" -ForegroundColor White
    Write-Host "3. Approval workflow requirements" -ForegroundColor White
    Write-Host "4. Policy enforcement timing or validation order" -ForegroundColor White

} catch {
    Write-Error "Error: $($_.Exception.Message)"
    Write-Host "Full error details:" -ForegroundColor Red
    Write-Host $_.Exception.ToString() -ForegroundColor Red
}
