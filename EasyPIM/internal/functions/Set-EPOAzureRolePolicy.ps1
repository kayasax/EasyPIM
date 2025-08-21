#Requires -Version 5.1

function Set-EPOAzureRolePolicy {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PolicyDefinition,
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

    Write-Verbose "Applying Azure role policy for $($PolicyDefinition.RoleName) at $($PolicyDefinition.Scope)"

    $protectedAzureRoles = @("Owner","User Access Administrator")
    if ($protectedAzureRoles -contains $PolicyDefinition.RoleName) {
        Write-Warning "[WARNING] PROTECTED AZURE ROLE: '$($PolicyDefinition.RoleName)' is a critical role. Policy changes are blocked for security."
        Write-Host "[PROTECTED] Protected Azure role '$($PolicyDefinition.RoleName)' - policy change blocked" -ForegroundColor Yellow
        return @{ RoleName = $PolicyDefinition.RoleName; Scope = $PolicyDefinition.Scope; Status = "Protected (No Changes)"; Mode = $Mode; Details = "Azure role is protected from policy changes for security reasons" }
    }

    if ($Mode -eq "validate") {
        $policy = $PolicyDefinition.ResolvedPolicy
        Write-Host "[INFO] Policy Changes for Azure Role '$($PolicyDefinition.RoleName)' at '$($PolicyDefinition.Scope)':" -ForegroundColor Cyan
        Write-Host "   [TIME] Activation Duration: $($policy.ActivationDuration)" -ForegroundColor Yellow
        Write-Host "   [LOCK] Activation Requirements: $($policy.ActivationRequirement)" -ForegroundColor Yellow
        if ($policy.ActiveAssignmentRequirement) { Write-Host "   [SECURE] Active Assignment Requirements: $($policy.ActiveAssignmentRequirement)" -ForegroundColor Yellow }
        Write-Host "   [OK] Approval Required: $($policy.ApprovalRequired)" -ForegroundColor Yellow
        if ($policy.Approvers -and $policy.ApprovalRequired -eq $true) { Write-Host "   [USERS] Approvers: $($policy.Approvers.Count) configured" -ForegroundColor Yellow }
        Write-Host "   [TARGET] Max Eligibility Duration: $($policy.MaximumEligibilityDuration)" -ForegroundColor Yellow
        Write-Host "   [FAST] Max Active Duration: $($policy.MaximumActiveAssignmentDuration)" -ForegroundColor Yellow
        $notificationCount = 0; $policy.PSObject.Properties | Where-Object { $_.Name -like "Notification_*" } | ForEach-Object { $notificationCount++ }
        if ($notificationCount -gt 0) { Write-Host "   [EMAIL] Notification Settings: $notificationCount configured" -ForegroundColor Yellow }
        Write-Host "   [WARNING]  NOTE: No changes applied in validation mode" -ForegroundColor Magenta
        return @{ RoleName = $PolicyDefinition.RoleName; Scope = $PolicyDefinition.Scope; Status = "Validated (No Changes Applied)"; Mode = $Mode; Details = "Policy validation completed - changes would be applied in delta/initial mode" }
    }

    try {
        $existing = Get-PIMAzureResourcePolicy -tenantID $TenantId -subscriptionID $SubscriptionId -rolename $PolicyDefinition.RoleName -ErrorAction Stop
        if ($existing -and $existing.PolicyID) {
            if (-not $PolicyDefinition.PSObject.Properties['PolicyID']) { $PolicyDefinition | Add-Member -NotePropertyName PolicyID -NotePropertyValue $existing.PolicyID -Force } else { $PolicyDefinition.PolicyID = $existing.PolicyID }
            if ($existing.roleID -and -not $PolicyDefinition.PSObject.Properties['roleID']) { $PolicyDefinition | Add-Member -NotePropertyName roleID -NotePropertyValue $existing.roleID -Force }
        } else { Write-Verbose "Existing Azure role policy ID not found for $($PolicyDefinition.RoleName); will fallback to scope path (may fail to PATCH)." }
    } catch { Write-Verbose "Failed to resolve existing Azure policy ID: $($_.Exception.Message)" }

    Write-Verbose "[Policy][Azure] Building rules in-memory for $($PolicyDefinition.RoleName)"
    $resolved = $PolicyDefinition.ResolvedPolicy; if (-not $resolved) { $resolved = $PolicyDefinition }
    $propFallbacks = 'ActivationDuration','ActivationRequirement','ActiveAssignmentRequirement','AuthenticationContext_Enabled','AuthenticationContext_Value','ApprovalRequired','Approvers','MaximumEligibilityDuration','AllowPermanentEligibility','MaximumActiveAssignmentDuration','AllowPermanentActiveAssignment'
    foreach ($pn in $propFallbacks) { if (-not ($resolved.PSObject.Properties[$pn]) -and $PolicyDefinition.PSObject.Properties[$pn]) { try { $resolved | Add-Member -NotePropertyName $pn -NotePropertyValue $PolicyDefinition.$pn -Force } catch { $resolved.$pn = $PolicyDefinition.$pn }; Write-Verbose "[DirectApply][Fallback] Injected missing property '$pn' from top-level definition for role $($PolicyDefinition.RoleName)" } }
    $rules = @()
    if ($resolved.PSObject.Properties['ActivationDuration'] -and $resolved.ActivationDuration) { $rules += Set-ActivationDuration $resolved.ActivationDuration }
    if ($resolved.PSObject.Properties['ActivationRequirement']) { $rules += Set-ActivationRequirement $resolved.ActivationRequirement }
    if ($resolved.PSObject.Properties['ActiveAssignmentRequirement']) { $rules += Set-ActiveAssignmentRequirement $resolved.ActiveAssignmentRequirement }
    if ($resolved.PSObject.Properties['AuthenticationContext_Enabled'] -and $resolved.AuthenticationContext_Enabled) { $rules += Set-AuthenticationContext $resolved.AuthenticationContext_Enabled $resolved.AuthenticationContext_Value }
    if ($resolved.PSObject.Properties['ApprovalRequired'] -or $resolved.PSObject.Properties['Approvers']) { $rules += Set-Approval $resolved.ApprovalRequired $resolved.Approvers }
    if ($resolved.PSObject.Properties['MaximumEligibilityDuration'] -or $resolved.PSObject.Properties['AllowPermanentEligibility']) { $rules += Set-EligibilityAssignment $resolved.MaximumEligibilityDuration $resolved.AllowPermanentEligibility }
    if ($resolved.PSObject.Properties['MaximumActiveAssignmentDuration'] -or $resolved.PSObject.Properties['AllowPermanentActiveAssignment']) { $rules += Set-ActiveAssignment $resolved.MaximumActiveAssignmentDuration $resolved.AllowPermanentActiveAssignment }
    foreach ($n in $resolved.PSObject.Properties | Where-Object { $_.Name -like 'Notification_*' }) { switch ($n.Name) { 'Notification_EligibleAssignment_Alert' { $rules += Set-Notification_EligibleAssignment_Alert $n.Value } 'Notification_EligibleAssignment_Assignee' { $rules += Set-Notification_EligibleAssignment_Assignee $n.Value } 'Notification_EligibleAssignment_Approver' { $rules += Set-Notification_EligibleAssignment_Approver $n.Value } 'Notification_ActiveAssignment_Alert' { $rules += Set-Notification_ActiveAssignment_Alert $n.Value } 'Notification_ActiveAssignment_Assignee' { $rules += Set-Notification_ActiveAssignment_Assignee $n.Value } 'Notification_ActiveAssignment_Approver' { $rules += Set-Notification_ActiveAssignment_Approver $n.Value } 'Notification_Activation_Alert' { $rules += Set-Notification_Activation_Alert $n.Value } 'Notification_Activation_Assignee' { $rules += Set-Notification_Activation_Assignee $n.Value } 'Notification_Activation_Approver' { $rules += Set-Notification_Activation_Approver $n.Value } } }
    $bodyRules = $rules -join ","
    Write-Verbose "[Policy][Azure] Rule objects count: $($rules.Count)"
    if ($PSCmdlet.ShouldProcess("Azure role policy for $($PolicyDefinition.RoleName)", "PATCH policy")) {
        if (-not $PolicyDefinition.PolicyID) { Write-Verbose '[Policy][Azure] Missing PolicyID - attempting re-fetch'; try { $existing = Get-PIMAzureResourcePolicy -tenantID $TenantId -subscriptionID $SubscriptionId -rolename $PolicyDefinition.RoleName -ErrorAction Stop; if ($existing.PolicyID){$PolicyDefinition.PolicyID=$existing.PolicyID} } catch { Write-Verbose "[Policy][Azure] Re-fetch failed: $($_.Exception.Message)" } }
        if ($PolicyDefinition.PolicyID) { Update-Policy $PolicyDefinition.PolicyID $bodyRules } else { throw "Azure apply failed: No PolicyID for role $($PolicyDefinition.RoleName)" }
    }
    return @{ RoleName=$PolicyDefinition.RoleName; Scope=$PolicyDefinition.Scope; Status='Applied'; Mode=$Mode }
}
