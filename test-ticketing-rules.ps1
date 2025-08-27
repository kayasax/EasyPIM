# Test ticketing rules for User Administrator
Import-Module .\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psd1 -Force -Global

try {
    Connect-MgGraph -Scopes 'RoleManagement.Read.Directory' -NoWelcome

    # User Administrator role definition ID
    $roleDefId = "fe930be7-5e62-47db-91af-98c3a49a38b1"

    # Get role policy
    $rolePolicy = Get-MgRoleManagementDirectoryRoleAssignmentPolicy -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$roleDefId'"
    Write-Host "Found policy: $($rolePolicy.Id)"

    # Get all rules
    $policyRules = Get-MgRoleManagementDirectoryRoleAssignmentPolicyRule -UnifiedRoleManagementPolicyId $rolePolicy.Id

    # Check Enablement_Admin_Assignment rule for ticket requirements
    $enablementRule = $policyRules | Where-Object { $_.Id -eq "Enablement_Admin_Assignment" }
    if ($enablementRule) {
        Write-Host "=== Enablement_Admin_Assignment Rule ===" -ForegroundColor Yellow
        Write-Host "Enabled Rules: $($enablementRule.AdditionalProperties.enabledRules -join ', ')" -ForegroundColor Cyan

        # Check if TicketingRule is enabled
        if ($enablementRule.AdditionalProperties.enabledRules -contains "TicketingRule") {
            Write-Host "FOUND ISSUE: TicketingRule is required for adminAssign actions!" -ForegroundColor Red
            Write-Host "Solution: Add ticketInfo parameter to the request" -ForegroundColor Green
        } else {
            Write-Host "TicketingRule is NOT enabled" -ForegroundColor Green
        }
    }

    # Also check expiration rule duration
    $expirationRule = $policyRules | Where-Object { $_.Id -eq "Expiration_Admin_Assignment" }
    if ($expirationRule) {
        Write-Host "`n=== Expiration_Admin_Assignment Rule ===" -ForegroundColor Yellow
        Write-Host "Maximum Duration: '$($expirationRule.AdditionalProperties.maximumDuration)'" -ForegroundColor Cyan
        Write-Host "Is Expiration Required: $($expirationRule.AdditionalProperties.isExpirationRequired)" -ForegroundColor Cyan
    }

} catch {
    Write-Error "Error: $_"
}
