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
        [string]$Mode,
        [Parameter(Mandatory = $false)]
        [switch]$AllowProtectedRoles
    )

    # Delegate to the Core internal builder via public Set-PIMAzureResourcePolicy when possible, preserving behavior
    Write-Verbose "[Orchestrator] Applying Azure role policy for $($PolicyDefinition.RoleName) at $($PolicyDefinition.Scope)"

    $protectedAzureRoles = @("Owner","User Access Administrator")
    if ($protectedAzureRoles -contains $PolicyDefinition.RoleName) {
        if (-not $AllowProtectedRoles) {
            Write-Warning "[WARNING] PROTECTED AZURE ROLE: '$($PolicyDefinition.RoleName)' is a critical role. Policy changes are blocked for security."
            Write-Host "[PROTECTED] Protected Azure role '$($PolicyDefinition.RoleName)' - policy change blocked (use -AllowProtectedRoles to override)" -ForegroundColor Yellow
            return @{ RoleName = $PolicyDefinition.RoleName; Scope = $PolicyDefinition.Scope; Status = "Protected (No Changes)"; Mode = $Mode; Details = "Azure role is protected from policy changes for security reasons. Use -AllowProtectedRoles to override." }
        } else {
            Write-Warning "[SECURITY] OVERRIDE: Allowing policy changes to protected Azure role '$($PolicyDefinition.RoleName)'. This action will be logged for audit purposes."
            Write-Host "[SECURITY] PROTECTED ROLE OVERRIDE: Proceeding with policy changes to '$($PolicyDefinition.RoleName)' as requested" -ForegroundColor Red

            # Enhanced audit logging for protected role modifications
            $auditInfo = @{
                Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffK"
                Action = "ProtectedRoleOverride"
                RoleType = "Azure"
                RoleName = $PolicyDefinition.RoleName
                Scope = $PolicyDefinition.Scope
                TenantId = $TenantId
                SubscriptionId = $SubscriptionId
                User = $env:USERNAME
                Context = $env:USERDOMAIN
                Mode = $Mode
                PolicyChanges = $PolicyDefinition | ConvertTo-Json -Depth 5 -Compress
            }
            Write-Verbose "[AUDIT] Protected role override: $($auditInfo | ConvertTo-Json -Depth 3 -Compress)"
            try {
                Write-EventLog -LogName "Application" -Source "EasyPIM" -EventId 4001 -EntryType Warning -Message "Protected Azure role policy override: $($PolicyDefinition.RoleName) by $($env:USERNAME)" -ErrorAction SilentlyContinue
            } catch {
                Write-Verbose "[AUDIT] Could not write to Windows Event Log: $($_.Exception.Message)"
            }
        }
    }

    # Build parameter map for Set-PIMAzureResourcePolicy (Core public API)
    $params = @{
        tenantID = $TenantId
        rolename = @($PolicyDefinition.RoleName)
    }
    # Determine scope type: Management Group vs Subscription
    $scopeVal = $null
    if ($PolicyDefinition.PSObject.Properties['Scope'] -and $PolicyDefinition.Scope) { $scopeVal = [string]$PolicyDefinition.Scope }
    if ($scopeVal) {
        $normalizedScope = $scopeVal.TrimStart('/')
        if ($normalizedScope -like 'providers/Microsoft.Management/managementGroups/*') {
            $params.scope = $normalizedScope
        } elseif ($normalizedScope -like 'subscriptions/*') {
            $params.subscriptionID = $SubscriptionId
            $params.scope = $normalizedScope
        } else {
            # Unknown prefix: fall back to explicit Scope if provided; do not force subscription path
            $params.scope = $normalizedScope
        }
    } else {
        # No per-policy scope provided; fall back to subscription mode
        $params.subscriptionID = $SubscriptionId
    }
    Write-Verbose ("[DEBUG] Scope analysis: raw='{0}' normalized='{1}'" -f $scopeVal, $normalizedScope)
    Write-Verbose ("[DEBUG] Orchestrator param map for Set-PIMAzureResourcePolicy: {0}" -f ((($params.GetEnumerator() | Sort-Object Key) | ForEach-Object { "{0}='{1}'" -f $_.Key, $_.Value }) -join '; '))

    $resolved = $PolicyDefinition.ResolvedPolicy; if (-not $resolved) { $resolved = $PolicyDefinition }

    # Flatten notifications from templates
    try {
        if ($resolved.PSObject.Properties['Notifications'] -and $resolved.Notifications) {
            $n = $resolved.Notifications
            if ($n.PSObject.Properties['Eligibility'] -and $n.Eligibility) {
                if ($n.Eligibility.PSObject.Properties['Alert'] -and $n.Eligibility.Alert) { try { $resolved | Add-Member -NotePropertyName 'Notification_EligibleAssignment_Alert' -NotePropertyValue $n.Eligibility.Alert -Force } catch { $resolved.Notification_EligibleAssignment_Alert = $n.Eligibility.Alert } }
                if ($n.Eligibility.PSObject.Properties['Assignee'] -and $n.Eligibility.Assignee) { try { $resolved | Add-Member -NotePropertyName 'Notification_EligibleAssignment_Assignee' -NotePropertyValue $n.Eligibility.Assignee -Force } catch { $resolved.Notification_EligibleAssignment_Assignee = $n.Eligibility.Assignee } }
                if ($n.Eligibility.PSObject.Properties['Approvers'] -and $n.Eligibility.Approvers) { try { $resolved | Add-Member -NotePropertyName 'Notification_EligibleAssignment_Approver' -NotePropertyValue $n.Eligibility.Approvers -Force } catch { $resolved.Notification_EligibleAssignment_Approver = $n.Eligibility.Approvers } }
            }
            if ($n.PSObject.Properties['Active'] -and $n.Active) {
                if ($n.Active.PSObject.Properties['Alert'] -and $n.Active.Alert) { try { $resolved | Add-Member -NotePropertyName 'Notification_ActiveAssignment_Alert' -NotePropertyValue $n.Active.Alert -Force } catch { $resolved.Notification_ActiveAssignment_Alert = $n.Active.Alert } }
                if ($n.Active.PSObject.Properties['Assignee'] -and $n.Active.Assignee) { try { $resolved | Add-Member -NotePropertyName 'Notification_ActiveAssignment_Assignee' -NotePropertyValue $n.Active.Assignee -Force } catch { $resolved.Notification_ActiveAssignment_Assignee = $n.Active.Assignee } }
                if ($n.Active.PSObject.Properties['Approvers'] -and $n.Active.Approvers) { try { $resolved | Add-Member -NotePropertyName 'Notification_ActiveAssignment_Approver' -NotePropertyValue $n.Active.Approvers -Force } catch { $resolved.Notification_ActiveAssignment_Approver = $n.Active.Approvers } }
            }
            if ($n.PSObject.Properties['Activation'] -and $n.Activation) {
                if ($n.Activation.PSObject.Properties['Alert'] -and $n.Activation.Alert) { try { $resolved | Add-Member -NotePropertyName 'Notification_Activation_Alert' -NotePropertyValue $n.Activation.Alert -Force } catch { $resolved.Notification_Activation_Alert = $n.Activation.Alert } }
                if ($n.Activation.PSObject.Properties['Assignee'] -and $n.Activation.Assignee) { try { $resolved | Add-Member -NotePropertyName 'Notification_Activation_Assignee' -NotePropertyValue $n.Activation.Assignee -Force } catch { $resolved.Notification_Activation_Assignee = $n.Activation.Assignee } }
                if ($n.Activation.PSObject.Properties['Approvers'] -and $n.Activation.Approvers) { try { $resolved | Add-Member -NotePropertyName 'Notification_Activation_Approver' -NotePropertyValue $n.Activation.Approvers -Force } catch { $resolved.Notification_Activation_Approver = $n.Activation.Approvers } }
            }
        }
    } catch { Write-Verbose ("[Policy][Azure] Notification flattening skipped: {0}" -f $_.Exception.Message) }

    # Normalize Notification_* to Hashtable
    try {
        function Convert-ToNotifHashtable { param([Parameter(Mandatory)][object]$Obj) $h=@{}; $getVal={param($o,[string]$name) if ($o -is [hashtable]) {return $o[$name]} if ($o -is [pscustomobject]) {return ($o.PSObject.Properties[$name]).Value} return $null}; $boolVal=$getVal.Invoke($Obj,'isDefaultRecipientEnabled'); if ($null -eq $boolVal) { $boolVal = $getVal.Invoke($Obj,'isDefaultRecipientsEnabled') } if ($null -ne $boolVal) { $h['isDefaultRecipientEnabled']=[bool]$boolVal } else { $h['isDefaultRecipientEnabled']=$true }; $level=$getVal.Invoke($Obj,'notificationLevel'); if ($null -eq $level) { $level=$getVal.Invoke($Obj,'NotificationLevel') } if ($null -ne $level) { $h['notificationLevel']="${level}" } else { $h['notificationLevel']='All' }; $recips=$getVal.Invoke($Obj,'Recipients'); if ($null -eq $recips) { $recips=$getVal.Invoke($Obj,'recipients') } if ($null -eq $recips) { $h['Recipients']=@() } elseif ($recips -is [string]) { $h['Recipients']=($recips -split ',') | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ } } else { $h['Recipients']=@($recips | ForEach-Object { $_.ToString() }) } return $h }
        foreach ($np in @('Notification_EligibleAssignment_Alert','Notification_EligibleAssignment_Assignee','Notification_EligibleAssignment_Approver','Notification_ActiveAssignment_Alert','Notification_ActiveAssignment_Assignee','Notification_ActiveAssignment_Approver','Notification_Activation_Alert','Notification_Activation_Assignee','Notification_Activation_Approver')) { if ($resolved.PSObject.Properties[$np] -and $null -ne $resolved.$np) { $resolved.$np = Convert-ToNotifHashtable -Obj $resolved.$np } }
    } catch { Write-Verbose ("[Policy][Azure] Notification normalization skipped: {0}" -f $_.Exception.Message) }

    # Apply business rules validation to handle MFA/Authentication Context conflicts
    Write-Verbose "[DEBUG] Azure role '$($PolicyDefinition.RoleName)': Checking for Auth Context conflicts"
    Write-Verbose "[DEBUG] AuthenticationContext_Enabled: $($resolved.PSObject.Properties['AuthenticationContext_Enabled'] -and $resolved.AuthenticationContext_Enabled)"
    Write-Verbose "[DEBUG] ActivationRequirement exists: $($resolved.PSObject.Properties['ActivationRequirement'] -and $resolved.ActivationRequirement)"
    Write-Verbose "[DEBUG] ActivationRequirement value: $($resolved.ActivationRequirement)"

    if ($resolved.PSObject.Properties['AuthenticationContext_Enabled'] -and $resolved.AuthenticationContext_Enabled -and
        $resolved.PSObject.Properties['ActivationRequirement'] -and $resolved.ActivationRequirement) {

        Write-Verbose "[DEBUG] Calling Test-PIMPolicyBusinessRules for Azure role '$($PolicyDefinition.RoleName)'"
        $businessRuleResult = Test-PIMPolicyBusinessRules -PolicySettings $resolved -ApplyAdjustments

        if ($businessRuleResult.HasConflicts) {
            Write-Verbose "[DEBUG] Business rules found $($businessRuleResult.Conflicts.Count) conflicts"
            foreach ($conflict in $businessRuleResult.Conflicts) {
                if ($conflict.Type -eq 'AuthenticationContextMfaConflict') {
                    Write-Warning $conflict.Message
                    Write-Verbose "[DEBUG] Adjusting ActivationRequirement from '$($resolved.ActivationRequirement)' to '$($conflict.AdjustedValue)'"
                    $resolved.ActivationRequirement = $conflict.AdjustedValue
                }
            }
        } else {
            Write-Verbose "[DEBUG] No business rule conflicts found"
        }
    }

    # Map fields that the public cmdlet supports
    if ($resolved.PSObject.Properties['ActivationDuration'] -and $resolved.ActivationDuration) { $params.ActivationDuration = $resolved.ActivationDuration }
    if ($resolved.PSObject.Properties['ActivationRequirement']) {
        $ar = $resolved.ActivationRequirement
        if ($ar -is [string]) { if ($ar -match ',') { $ar = ($ar -split ',') | ForEach-Object { $_.ToString().Trim() } } else { $ar = @($ar) } }
        elseif (-not ($ar -is [System.Collections.IEnumerable])) { $ar = @($ar) }
        $params.ActivationRequirement = $ar
    }
    if ($resolved.PSObject.Properties['ActiveAssignmentRequirement']) { $params.ActiveAssignationRequirement = $resolved.ActiveAssignmentRequirement }
    if ($resolved.PSObject.Properties['AuthenticationContext_Enabled']) { $params.AuthenticationContext_Enabled = $resolved.AuthenticationContext_Enabled }
    if ($resolved.PSObject.Properties['AuthenticationContext_Value']) { $params.AuthenticationContext_Value = $resolved.AuthenticationContext_Value }
    if ($resolved.PSObject.Properties['ApprovalRequired']) { $params.ApprovalRequired = $resolved.ApprovalRequired }
    if ($resolved.PSObject.Properties['Approvers']) {
        # Convert approver format from config {id, description} to Set-PIMAzureResourcePolicy {Id, Name}
        $convertedApprovers = @()
        foreach ($approver in $resolved.Approvers) {
            if ($approver -is [string]) {
                # Simple string ID - convert to hashtable
                $convertedApprovers += @{ Id = $approver; Name = $approver; Type = "user" }
            } else {
                # Object format - map properties correctly
                $convertedApprover = @{}
                if ($approver.PSObject.Properties['id']) { $convertedApprover.Id = $approver.id }
                elseif ($approver.PSObject.Properties['Id']) { $convertedApprover.Id = $approver.Id }

                if ($approver.PSObject.Properties['description']) { $convertedApprover.Name = $approver.description }
                elseif ($approver.PSObject.Properties['Name']) { $convertedApprover.Name = $approver.Name }
                else { $convertedApprover.Name = $convertedApprover.Id }

                if ($approver.PSObject.Properties['Type']) { $convertedApprover.Type = $approver.Type }
                # Do NOT set default type - let auto-detection handle it

                $convertedApprovers += $convertedApprover
            }
        }
        $params.Approvers = $convertedApprovers
    }
    if ($resolved.PSObject.Properties['MaximumEligibilityDuration'] -and $resolved.MaximumEligibilityDuration) { $params.MaximumEligibilityDuration = $resolved.MaximumEligibilityDuration }
    if ($resolved.PSObject.Properties['AllowPermanentEligibility']) { $params.AllowPermanentEligibility = $resolved.AllowPermanentEligibility }
    # PT0S prevention: Only set MaximumActiveAssignmentDuration if it has a non-empty value to prevent PT0S conversion
    if ($resolved.PSObject.Properties['MaximumActiveAssignmentDuration'] -and $resolved.MaximumActiveAssignmentDuration) {
        # Additional validation to ensure value is not PT0S and meets minimum requirement
        $duration = [string]$resolved.MaximumActiveAssignmentDuration
        if ($duration -ne "PT0S" -and $duration -ne "PT0M" -and $duration -ne "PT0H" -and $duration -ne "P0D") {
            $params.MaximumActiveAssignmentDuration = $resolved.MaximumActiveAssignmentDuration
        } else {
            Write-Warning "[PT0S Prevention] Skipping MaximumActiveAssignmentDuration '$duration' for Azure role '$($PolicyDefinition.RoleName)' - zero duration values are not allowed"
        }
    }
    if ($resolved.PSObject.Properties['AllowPermanentActiveAssignment']) { $params.AllowPermanentActiveAssignment = $resolved.AllowPermanentActiveAssignment }
    foreach ($n in $resolved.PSObject.Properties | Where-Object { $_.Name -like 'Notification_*' }) { $params[$n.Name] = $n.Value }

    $status = 'Applied'
    if ($PSCmdlet.ShouldProcess("Azure role policy for $($PolicyDefinition.RoleName)", "Apply via Set-PIMAzureResourcePolicy")) {
        if (Get-Command -Name Set-PIMAzureResourcePolicy -ErrorAction SilentlyContinue) {
            try { Set-PIMAzureResourcePolicy @params -Verbose:$VerbosePreference | Out-Null }
            catch { Write-Warning "Set-PIMAzureResourcePolicy failed: $($_.Exception.Message)"; $status='Failed' }
        } else { Write-Warning 'Set-PIMAzureResourcePolicy cmdlet not found.'; $status='CmdletMissing' }
    } else { $status='Skipped' }

    return @{ RoleName=$PolicyDefinition.RoleName; Scope=$PolicyDefinition.Scope; Status=$status; Mode=$Mode }
}
