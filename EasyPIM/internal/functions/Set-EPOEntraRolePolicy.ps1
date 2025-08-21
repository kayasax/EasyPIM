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

    # Flatten nested Notifications (from templates) into Notification_* properties expected by rule builders
    try {
        if ($resolved.PSObject.Properties['Notifications'] -and $resolved.Notifications) {
            $n = $resolved.Notifications
            # Eligibility
            if ($n.PSObject.Properties['Eligibility'] -and $n.Eligibility) {
                if ($n.Eligibility.PSObject.Properties['Alert'] -and $n.Eligibility.Alert) { try { $resolved | Add-Member -NotePropertyName 'Notification_EligibleAssignment_Alert' -NotePropertyValue $n.Eligibility.Alert -Force } catch { $resolved.Notification_EligibleAssignment_Alert = $n.Eligibility.Alert } }
                if ($n.Eligibility.PSObject.Properties['Assignee'] -and $n.Eligibility.Assignee) { try { $resolved | Add-Member -NotePropertyName 'Notification_EligibleAssignment_Assignee' -NotePropertyValue $n.Eligibility.Assignee -Force } catch { $resolved.Notification_EligibleAssignment_Assignee = $n.Eligibility.Assignee } }
                if ($n.Eligibility.PSObject.Properties['Approvers'] -and $n.Eligibility.Approvers) { try { $resolved | Add-Member -NotePropertyName 'Notification_EligibleAssignment_Approver' -NotePropertyValue $n.Eligibility.Approvers -Force } catch { $resolved.Notification_EligibleAssignment_Approver = $n.Eligibility.Approvers } }
            }
            # Active
            if ($n.PSObject.Properties['Active'] -and $n.Active) {
                if ($n.Active.PSObject.Properties['Alert'] -and $n.Active.Alert) { try { $resolved | Add-Member -NotePropertyName 'Notification_ActiveAssignment_Alert' -NotePropertyValue $n.Active.Alert -Force } catch { $resolved.Notification_ActiveAssignment_Alert = $n.Active.Alert } }
                if ($n.Active.PSObject.Properties['Assignee'] -and $n.Active.Assignee) { try { $resolved | Add-Member -NotePropertyName 'Notification_ActiveAssignment_Assignee' -NotePropertyValue $n.Active.Assignee -Force } catch { $resolved.Notification_ActiveAssignment_Assignee = $n.Active.Assignee } }
                if ($n.Active.PSObject.Properties['Approvers'] -and $n.Active.Approvers) { try { $resolved | Add-Member -NotePropertyName 'Notification_ActiveAssignment_Approver' -NotePropertyValue $n.Active.Approvers -Force } catch { $resolved.Notification_ActiveAssignment_Approver = $n.Active.Approvers } }
            }
            # Activation
            if ($n.PSObject.Properties['Activation'] -and $n.Activation) {
                if ($n.Activation.PSObject.Properties['Alert'] -and $n.Activation.Alert) { try { $resolved | Add-Member -NotePropertyName 'Notification_Activation_Alert' -NotePropertyValue $n.Activation.Alert -Force } catch { $resolved.Notification_Activation_Alert = $n.Activation.Alert } }
                if ($n.Activation.PSObject.Properties['Assignee'] -and $n.Activation.Assignee) { try { $resolved | Add-Member -NotePropertyName 'Notification_Activation_Assignee' -NotePropertyValue $n.Activation.Assignee -Force } catch { $resolved.Notification_Activation_Assignee = $n.Activation.Assignee } }
                if ($n.Activation.PSObject.Properties['Approvers'] -and $n.Activation.Approvers) { try { $resolved | Add-Member -NotePropertyName 'Notification_Activation_Approver' -NotePropertyValue $n.Activation.Approvers -Force } catch { $resolved.Notification_Activation_Approver = $n.Activation.Approvers } }
            }
        }
    } catch { Write-Verbose ("[Policy][Entra] Notification flattening skipped: {0}" -f $_.Exception.Message) }
    # Pre-validate approver principals exist (avoids InvalidPolicy on PATCH when approvers do not exist)
    try {
        if ($resolved.PSObject.Properties['Approvers'] -and $resolved.Approvers) {
            $missingApprovers = @()
            foreach ($ap in @($resolved.Approvers)) {
                $apId = $null
                if ($ap -is [string]) { $apId = $ap }
                else { $apId = $ap.Id; if (-not $apId) { $apId = $ap.id } }
                if ($apId) {
                    if (-not (Test-PrincipalExists -PrincipalId $apId)) {
                        $missingApprovers += [pscustomobject]@{ PrincipalId = [string]$apId; RoleName = $PolicyDefinition.RoleName }
                    }
                }
            }
            if ($missingApprovers.Count -gt 0) {
                $ids = ($missingApprovers | Select-Object -ExpandProperty PrincipalId -Unique) -join ', '
                throw "Approver principal(s) not found for role '$($PolicyDefinition.RoleName)': $ids"
            }
        }
    } catch {
        throw $_
    }
    # Resolve role ID and policy ID early; skip if not found
    try {
        $live = Get-PIMEntraRolePolicy -tenantID $TenantId -rolename $PolicyDefinition.RoleName -ErrorAction Stop
    } catch {
        Write-Warning "[SKIP] Entra role '$($PolicyDefinition.RoleName)' not found in this tenant; skipping."
        return @{ RoleName = $PolicyDefinition.RoleName; Status = "Skipped (Role Not Found)"; Mode = $Mode }
    }
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
    try { $existing = $live } catch { Write-Verbose "[Policy][Entra] Could not read live policy to compute effective AC: $($_.Exception.Message)" }
    $acEnabledEffective = $false
    if ($resolved.PSObject.Properties['AuthenticationContext_Enabled'] -and [bool]([string]$resolved.AuthenticationContext_Enabled)) { $acEnabledEffective = $true }
    elseif ($existing -and ($existing.AuthenticationContext_Enabled -eq $true -or [string]$existing.AuthenticationContext_Enabled -eq 'true')) { $acEnabledEffective = $true }

    $rules = @()
    if ($resolved.PSObject.Properties['ActivationDuration'] -and $resolved.ActivationDuration) { $rules += Set-ActivationDuration $resolved.ActivationDuration -EntraRole }
    if ($resolved.PSObject.Properties['ActivationRequirement']) {
        $activationReqEffective = $resolved.ActivationRequirement
        # Normalize to array of strings
        if ($null -ne $activationReqEffective) {
            if ($activationReqEffective -is [string]) {
                if ($activationReqEffective -match ',') { $activationReqEffective = ($activationReqEffective -split ',') } else { $activationReqEffective = @($activationReqEffective) }
            } elseif (-not ($activationReqEffective -is [System.Collections.IEnumerable])) {
                $activationReqEffective = @($activationReqEffective)
            }
        } else { $activationReqEffective = @() }

        if ($acEnabledEffective) {
            # When AC is enabled, MFA must not be enabled. Remove any MFA tokens and still send the enablement rule to clear existing MFA on the policy.
            $before = ($activationReqEffective | Measure-Object).Count
            $activationReqEffective = @($activationReqEffective | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -and ($_ -ne 'MFA') -and ($_ -ne 'MultiFactorAuthentication') })
            $after = ($activationReqEffective | Measure-Object).Count
            Write-Verbose ("[Policy][Entra] AC enabled: filtered MFA from Enablement_EndUser_Assignment (removed {0} item(s))." -f ($before - $after))
        }

        # Always emit the enablement rule (possibly empty) so we can clear MFA if previously set
        $rules += Set-ActivationRequirement $activationReqEffective -EntraRole
    }
    if ($resolved.PSObject.Properties['ActiveAssignmentRequirement']) { $rules += Set-ActiveAssignmentRequirement $resolved.ActiveAssignmentRequirement -EntraRole }
    if ($resolved.PSObject.Properties['AuthenticationContext_Enabled'] -and (_ResolveBool $resolved.AuthenticationContext_Enabled)) {
        # Pre-validate claim format (e.g., c1..c25)
        $claim = [string]$resolved.AuthenticationContext_Value
        if (-not [string]::IsNullOrWhiteSpace($claim)) {
            if ($claim -notmatch '^c([1-9]|1\d|2[0-5])$') {
                throw "Invalid AuthenticationContext_Value '$claim'. Use c1..c25."
            }
            # Pre-validate the Authentication Context exists in the tenant (avoid InvalidPolicy on PATCH)
            try {
                $acEndpoint = "identity/conditionalAccess/authenticationContextClassReferences/$claim"
                $ac = invoke-graph -Endpoint $acEndpoint -Method GET -NoPagination -ErrorAction Stop
                # Some tenants expose 'isAvailable' or 'state'; accept if the object exists and not explicitly disabled
                $isAvailable = $false
                if ($null -ne $ac) {
                    if ($ac.PSObject.Properties['isAvailable']) { $isAvailable = [bool]$ac.isAvailable }
                    elseif ($ac.PSObject.Properties['state']) { $isAvailable = ([string]$ac.state -match 'enabled|available|published') }
                    else { $isAvailable = $true } # object exists; assume usable
                }
                if (-not $isAvailable) { throw "Authentication Context '$claim' exists but is not available/enabled (state=$($ac.state); isAvailable=$($ac.isAvailable))." }
            } catch {
                throw "Authentication Context '$claim' not found or unavailable in this tenant. Define and publish it under Conditional Access > Authentication context first. Details: $($_.Exception.Message)"
            }
        }
        $rules += Set-AuthenticationContext $true $resolved.AuthenticationContext_Value -EntraRole
    }
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
        try { if ($live -and $live.PolicyID) { $PolicyDefinition | Add-Member -NotePropertyName PolicyID -NotePropertyValue $live.PolicyID -Force } } catch { Write-Verbose "[Policy][Entra] Failed to resolve PolicyID: $($_.Exception.Message)" }
    if ($PolicyDefinition.PSObject.Properties['PolicyID'] -and $PolicyDefinition.PolicyID) { Write-Verbose "[Policy][Entra] Using Graph updater for PolicyID $($PolicyDefinition.PolicyID)"; Update-EntraRolePolicy $PolicyDefinition.PolicyID $rules }
        else { throw "Entra apply failed: No PolicyID for role $($PolicyDefinition.RoleName)" }
    }
    return @{ RoleName=$PolicyDefinition.RoleName; Status='Applied'; Mode=$Mode }
}
