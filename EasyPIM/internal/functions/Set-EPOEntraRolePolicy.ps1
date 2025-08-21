#Requires -Version 5.1

function Set-EPOEntraRolePolicy {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PolicyDefinition,
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

    Write-Verbose "Applying Entra role policy for $($PolicyDefinition.RoleName)"

    $protectedRoles = @("Global Administrator","Privileged Role Administrator","Security Administrator","User Access Administrator")
    if ($protectedRoles -contains $PolicyDefinition.RoleName) {
        Write-Warning "[WARNING] PROTECTED ROLE: '$($PolicyDefinition.RoleName)' is a critical role. Policy changes are blocked for security."
        Write-Host "[PROTECTED] Protected role '$($PolicyDefinition.RoleName)' - policy change blocked" -ForegroundColor Yellow
        return @{ RoleName = $PolicyDefinition.RoleName; Status = "Protected (No Changes)"; Mode = $Mode; Details = "Role is protected from policy changes for security reasons" }
    }

    if ($Mode -eq "validate") {
        $policy = $PolicyDefinition.ResolvedPolicy
        Write-Host "[INFO] Policy Changes for Entra Role '$($PolicyDefinition.RoleName)':" -ForegroundColor Cyan
        Write-Host "   [TIME] Activation Duration: $($policy.ActivationDuration)" -ForegroundColor Yellow
        Write-Host "   [LOCK] Activation Requirements: $($policy.ActivationRequirement)" -ForegroundColor Yellow
        if ($policy.ActiveAssignmentRequirement) { Write-Host "   [SECURE] Active Assignment Requirements: $($policy.ActiveAssignmentRequirement)" -ForegroundColor Yellow }
        Write-Host "   [OK] Approval Required: $($policy.ApprovalRequired)" -ForegroundColor Yellow
        if ($policy.Approvers -and $policy.ApprovalRequired -eq $true) { Write-Host "   [USERS] Approvers: $($policy.Approvers.Count) configured" -ForegroundColor Yellow }
        Write-Host "   [TARGET] Max Eligibility Duration: $($policy.MaximumEligibilityDuration)" -ForegroundColor Yellow
        Write-Host "   [FAST] Max Active Duration: $($policy.MaximumActiveAssignmentDuration)" -ForegroundColor Yellow
        if ($policy.AuthenticationContext_Enabled -eq $true) { Write-Host "   [PROTECTED] Auth Context: $($policy.AuthenticationContext_Value)" -ForegroundColor Yellow }
        $notificationCount = 0; $policy.PSObject.Properties | Where-Object { $_.Name -like "Notification_*" } | ForEach-Object { $notificationCount++ }
        if ($notificationCount -gt 0) { Write-Host "   [EMAIL] Notification Settings: $notificationCount configured" -ForegroundColor Yellow }
        Write-Host "   [WARNING]  NOTE: No changes applied in validation mode" -ForegroundColor Magenta
        return @{ RoleName = $PolicyDefinition.RoleName; Status = "Validated (No Changes Applied)"; Mode = $Mode; Details = "Policy validation completed - changes would be applied in delta/initial mode" }
    }

    $resolved = $PolicyDefinition.ResolvedPolicy; if (-not $resolved) { $resolved = $PolicyDefinition }
    function _ResolveBool($v) {
        if ($null -eq $v) { return $false }
        if ($v -is [bool]) { return $v }
        $s = ([string]$v).Trim()
        if ($s -match '^(?i:true|1|yes)$') { return $true }
        if ($s -match '^(?i:false|0|no)$') { return $false }
        # Fallback: non-empty string treated as false to avoid accidental truthiness
        return $false
    }
    $propFallbacks = 'ActivationDuration','ActivationRequirement','ActiveAssignmentRequirement','AuthenticationContext_Enabled','AuthenticationContext_Value','ApprovalRequired','Approvers','MaximumEligibilityDuration','AllowPermanentEligibility','MaximumActiveAssignmentDuration','AllowPermanentActiveAssignment'
    foreach ($pn in $propFallbacks) { if (-not ($resolved.PSObject.Properties[$pn]) -and $PolicyDefinition.PSObject.Properties[$pn]) { try { $resolved | Add-Member -NotePropertyName $pn -NotePropertyValue $PolicyDefinition.$pn -Force } catch { $resolved.$pn = $PolicyDefinition.$pn } } }

    # Determine effective Authentication Context state: template OR live policy
    $existing = $null
    try { $existing = Get-PIMEntraRolePolicy -tenantID $TenantId -rolename $PolicyDefinition.RoleName -ErrorAction Stop } catch { Write-Verbose "[Policy][Entra] Could not read live policy to compute effective AC: $($_.Exception.Message)" }
    $acEnabledEffective = $false
    if ($resolved.PSObject.Properties['AuthenticationContext_Enabled'] -and [bool]([string]$resolved.AuthenticationContext_Enabled)) { $acEnabledEffective = $true }
    elseif ($existing -and ($existing.AuthenticationContext_Enabled -eq $true -or [string]$existing.AuthenticationContext_Enabled -eq 'true')) { $acEnabledEffective = $true }

    $rules = @()
    if ($resolved.PSObject.Properties['ActivationDuration'] -and $resolved.ActivationDuration) { $rules += Set-ActivationDuration $resolved.ActivationDuration -EntraRole }
    if ($resolved.PSObject.Properties['ActivationRequirement']) {
        $activationReqEffective = $resolved.ActivationRequirement
        if ($acEnabledEffective) {
            # Silent MFA removal when Authentication Context is enabled to avoid Graph conflict
            if ($null -ne $activationReqEffective) {
                # Normalize to array of strings
                if ($activationReqEffective -is [string]) {
                    if ($activationReqEffective -match ',') { $activationReqEffective = ($activationReqEffective -split ',') } else { $activationReqEffective = @($activationReqEffective) }
                } elseif (-not ($activationReqEffective -is [System.Collections.IEnumerable])) {
                    $activationReqEffective = @($activationReqEffective)
                }
                # Remove MFA tokens (canonical, abbreviations, variants like require-mfa, multi-factor, etc.)
                $activationReqEffective = @(
                    foreach ($it in $activationReqEffective) {
                        $t = ($it | ForEach-Object { $_.ToString().Trim() })
                        $norm = ($t -replace '[^a-zA-Z]', '').ToLowerInvariant()
                        $isMfa = ($norm -eq 'mfa' -or $norm -eq 'requiremfa' -or $norm -like 'multifactorauthentication*' -or $norm -like 'multifactor*')
                        if (-not $isMfa) { $t }
                    }
                )
            }
        }
        $rules += Set-ActivationRequirement $activationReqEffective -EntraRole
    }
    if ($resolved.PSObject.Properties['ActiveAssignmentRequirement']) { $rules += Set-ActiveAssignmentRequirement $resolved.ActiveAssignmentRequirement -EntraRole }
    if ($resolved.PSObject.Properties['AuthenticationContext_Enabled'] -and (_ResolveBool $resolved.AuthenticationContext_Enabled)) { $rules += Set-AuthenticationContext $true $resolved.AuthenticationContext_Value -EntraRole }
    # Only include approval rule when actually needed: ApprovalRequired is true OR approvers are explicitly provided
    $approvalReq = ($resolved.PSObject.Properties['ApprovalRequired'] -and (_ResolveBool $resolved.ApprovalRequired))
    $approverCount = 0; if ($resolved.PSObject.Properties['Approvers'] -and $resolved.Approvers) { $approverCount = (@($resolved.Approvers)).Count }
    Write-Verbose ("[Policy][Entra] Approval gating: Required={0}, ApproverCount={1}" -f $approvalReq, $approverCount)
    if ($approvalReq -or ($approverCount -gt 0)) {
        $rules += Set-Approval $approvalReq $resolved.Approvers -EntraRole
    }
    if ($resolved.PSObject.Properties['MaximumEligibilityDuration'] -or $resolved.PSObject.Properties['AllowPermanentEligibility']) { $rules += Set-EligibilityAssignment $resolved.MaximumEligibilityDuration $resolved.AllowPermanentEligibility -EntraRole }
    if ($resolved.PSObject.Properties['MaximumActiveAssignmentDuration'] -or $resolved.PSObject.Properties['AllowPermanentActiveAssignment']) { $rules += Set-ActiveAssignment $resolved.MaximumActiveAssignmentDuration $resolved.AllowPermanentActiveAssignment -EntraRole }
    foreach ($n in $resolved.PSObject.Properties | Where-Object { $_.Name -like 'Notification_*' }) { switch ($n.Name) { 'Notification_EligibleAssignment_Alert' { $rules += Set-Notification_EligibleAssignment_Alert $n.Value -EntraRole } 'Notification_EligibleAssignment_Assignee' { $rules += Set-Notification_EligibleAssignment_Assignee $n.Value -EntraRole } 'Notification_EligibleAssignment_Approver' { $rules += Set-Notification_EligibleAssignment_Approver $n.Value -EntraRole } 'Notification_ActiveAssignment_Alert' { $rules += Set-Notification_ActiveAssignment_Alert $n.Value -EntraRole } 'Notification_ActiveAssignment_Assignee' { $rules += Set-Notification_ActiveAssignment_Assignee $n.Value -EntraRole } 'Notification_ActiveAssignment_Approver' { $rules += Set-Notification_ActiveAssignment_Approver $n.Value -EntraRole } 'Notification_Activation_Alert' { $rules += Set-Notification_Activation_Alert $n.Value -EntraRole } 'Notification_Activation_Assignee' { $rules += Set-Notification_Activation_Assignee $n.Value -EntraRole } 'Notification_Activation_Approver' { $rules += Set-Notification_Activation_Approver $n.Value -EntraRole } } }
    Write-Verbose "[Policy][Entra] Rule objects count: $($rules.Count)"
    if ($PSCmdlet.ShouldProcess("Entra role policy for $($PolicyDefinition.RoleName)", "PATCH policy")) {
        try { $existing = Get-PIMEntraRolePolicy -tenantID $TenantId -rolename $PolicyDefinition.RoleName -ErrorAction Stop; if ($existing -and $existing.PolicyID) { $PolicyDefinition | Add-Member -NotePropertyName PolicyID -NotePropertyValue $existing.PolicyID -Force } } catch { Write-Verbose "[Policy][Entra] Failed to resolve PolicyID: $($_.Exception.Message)" }
    if ($PolicyDefinition.PSObject.Properties['PolicyID'] -and $PolicyDefinition.PolicyID) { Write-Verbose "[Policy][Entra] Using Graph updater for PolicyID $($PolicyDefinition.PolicyID)"; Update-EntraRolePolicy $PolicyDefinition.PolicyID $rules }
        else { throw "Entra apply failed: No PolicyID for role $($PolicyDefinition.RoleName)" }
    }
    return @{ RoleName=$PolicyDefinition.RoleName; Status='Applied'; Mode=$Mode }
}
