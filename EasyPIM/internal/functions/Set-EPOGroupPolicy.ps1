#Requires -Version 5.1

function Set-EPOGroupPolicy {
    <#
    .SYNOPSIS
    Apply a PIM Group role policy using the Enhanced Policy Orchestrator.

    .DESCRIPTION
    Prepares and applies a group role policy by resolving GroupId, handling deferrals, flattening and normalizing notifications, normalizing requirements, and mapping legacy fields to expected parameters for Set-PIMGroupPolicy. AuthenticationContext_* is ignored for groups to avoid InvalidPolicy errors.

    .PARAMETER PolicyDefinition
    The group policy definition (optionally with ResolvedPolicy) to apply.

    .PARAMETER TenantId
    The target Entra tenant ID.

    .PARAMETER Mode
    One of delta or initial to control apply semantics.

    .PARAMETER SkipEligibilityCheck
    Skips the PIM eligibility pre-check for the target group.

    .EXAMPLE
    Set-EPOGroupPolicy -PolicyDefinition $p -TenantId $tid -WhatIf
    Shows what would change without applying any updates.

    .NOTES
    Defers group policies if the group isn't yet PIM-enabled; use Invoke-EPODeferredGroupPolicies to retry.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PolicyDefinition,
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        [Parameter(Mandatory = $true)]
        [string]$Mode,
        [Parameter(Mandatory = $false)]
        [switch]$SkipEligibilityCheck
    )

    # 1) Resolve GroupId if only GroupName was provided
    if (-not $PolicyDefinition.GroupId -and $PolicyDefinition.GroupName) {
        try { $endpoint = "groups?`$filter=displayName eq '$($PolicyDefinition.GroupName)'"; $resp = invoke-graph -Endpoint $endpoint; if ($resp.value -and $resp.value.Count -ge 1) { $PolicyDefinition | Add-Member -NotePropertyName GroupId -NotePropertyValue $resp.value[0].id -Force } else { throw "Unable to resolve GroupName '$($PolicyDefinition.GroupName)' to an Id" } } catch { Write-Warning "GroupName resolution failed: $($_.Exception.Message)" }
    }
    $groupRef = if ($PolicyDefinition.GroupId) { $PolicyDefinition.GroupId } else { $PolicyDefinition.GroupName }
    Write-Verbose "Applying Group policy for Group $groupRef role $($PolicyDefinition.RoleName)"

    # 1a) Ensure Graph authentication before any group policy operations (avoids false deferrals)
    try {
        $needConnect = $true
        try { $ctx = Get-MgContext } catch { $ctx = $null }
        if ($ctx -and $TenantId -and ($ctx.TenantId -eq $TenantId)) { $needConnect = $false }
        if ($needConnect) {
            $scopes = @(
                'RoleManagementPolicy.ReadWrite.Directory',
                'PrivilegedAccess.ReadWrite.AzureAD',
                'RoleManagement.ReadWrite.Directory',
                'RoleManagementPolicy.ReadWrite.AzureADGroup',
                'PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup',
                'PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup',
                'PrivilegedAccess.ReadWrite.AzureADGroup',
                'AuditLog.Read.All',
                'Directory.Read.All'
            )
            if ($TenantId) { Connect-MgGraph -Tenant $TenantId -Scopes $scopes -NoWelcome | Out-Null }
            else { Connect-MgGraph -Scopes $scopes -NoWelcome | Out-Null }
            Write-Verbose "[Policy][Group] Connected to Graph for tenant $TenantId"
        }
    } catch { Write-Verbose ("[Policy][Group] Graph connect skipped: {0}" -f $_.Exception.Message) }

    # 2) Eligibility pre-check (skip if explicitly bypassed)
    if (-not $SkipEligibilityCheck) {
        if (-not $PolicyDefinition.GroupId) { Write-Warning "Cannot check eligibility without GroupId for group name '$($PolicyDefinition.GroupName)'" }
        else { $eligible = $true; try { $eligible = Test-GroupEligibleForPIM -GroupId $PolicyDefinition.GroupId } catch { Write-Verbose "Eligibility check failed: $($_.Exception.Message)" }; if (-not $eligible) { if (-not $script:EasyPIM_DeferredGroupPolicies) { $script:EasyPIM_DeferredGroupPolicies = @() }; $script:EasyPIM_DeferredGroupPolicies += [PSCustomObject]@{ GroupId=$PolicyDefinition.GroupId; GroupName=$PolicyDefinition.GroupName; RoleName=$PolicyDefinition.RoleName; ResolvedPolicy=$PolicyDefinition.ResolvedPolicy; OriginalPolicy=$PolicyDefinition }; Write-Warning "Deferring Group policy for $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName) - group not PIM-eligible yet"; return @{ GroupId = $PolicyDefinition.GroupId; RoleName = $PolicyDefinition.RoleName; Status = 'DeferredNotEligible'; Mode = $Mode } } }
    }

    # 3) Validation short-circuit removed; use -WhatIf for preview

    # 4) Prepare the working policy object
    $resolved = if ($PolicyDefinition.ResolvedPolicy) { $PolicyDefinition.ResolvedPolicy } else { $PolicyDefinition }

    # 4a) Flatten Notifications from templates into Notification_* keys expected by Set-PIMGroupPolicy
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
    } catch { Write-Verbose ("[Policy][Group] Notification flattening skipped: {0}" -f $_.Exception.Message) }

    # 4b) Normalize each flattened Notification_* object into a true Hashtable
    #     This avoids parameter binder errors (PSCustomObject -> Hashtable) and standardizes keys/types:
    #       - isDefaultRecipientEnabled: [bool]
    #       - notificationLevel: string ('All'|'Critical')
    #       - Recipients: string[] (emails)
    #     The normalizer is tolerant to key casing and comma-delimited recipient strings.
    try {
        function Convert-ToNotifHashtable {
            param([Parameter(Mandatory)][object]$Obj)
            $h = @{}
            # Extract values with tolerant key lookup
            $getVal = {
                param($o, [string]$name)
                if ($o -is [hashtable]) { return $o[$name] }
                if ($o -is [pscustomobject]) { return ($o.PSObject.Properties[$name]).Value }
                return $null
            }
            $boolVal = $getVal.Invoke($Obj, 'isDefaultRecipientEnabled')
            if ($null -eq $boolVal) { $boolVal = $getVal.Invoke($Obj, 'isDefaultRecipientsEnabled') }
            if ($null -ne $boolVal) { $h['isDefaultRecipientEnabled'] = [bool]$boolVal } else { $h['isDefaultRecipientEnabled'] = $true }

            $level = $getVal.Invoke($Obj, 'notificationLevel'); if ($null -eq $level) { $level = $getVal.Invoke($Obj, 'NotificationLevel') }
            if ($null -ne $level) { $h['notificationLevel'] = "$level" } else { $h['notificationLevel'] = 'All' }

            $recips = $getVal.Invoke($Obj, 'Recipients'); if ($null -eq $recips) { $recips = $getVal.Invoke($Obj, 'recipients') }
            if ($null -eq $recips) { $h['Recipients'] = @() }
            elseif ($recips -is [string]) { $h['Recipients'] = ($recips -split ',') | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ } }
            else { $h['Recipients'] = @($recips | ForEach-Object { $_.ToString() }) }
            return $h
        }

        foreach ($np in @('Notification_EligibleAssignment_Alert','Notification_EligibleAssignment_Assignee','Notification_EligibleAssignment_Approver','Notification_ActiveAssignment_Alert','Notification_ActiveAssignment_Assignee','Notification_ActiveAssignment_Approver','Notification_Activation_Alert','Notification_Activation_Assignee','Notification_Activation_Approver')) {
            if ($resolved.PSObject.Properties[$np] -and $null -ne $resolved.$np) {
                $normalized = Convert-ToNotifHashtable -Obj $resolved.$np
                $resolved.$np = $normalized
            }
        }
    } catch { Write-Verbose ("[Policy][Group] Notification normalization skipped: {0}" -f $_.Exception.Message) }

    # 4c) Normalize schema aliases for consistency with downstream rule builders
    #     - Some templates use legacy names; map them to canonical names consumed by Set-PIMGroupPolicy.
    if (-not ($resolved.PSObject.Properties['ActivationRequirement']) -and $resolved.PSObject.Properties['EnablementRules'] -and $resolved.EnablementRules) { try { $resolved | Add-Member -NotePropertyName ActivationRequirement -NotePropertyValue $resolved.EnablementRules -Force } catch { $resolved.ActivationRequirement = $resolved.EnablementRules }; Write-Verbose "[GroupPolicy][Normalize] Added ActivationRequirement from EnablementRules for Group $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)" }
    if (-not ($resolved.PSObject.Properties['ActivationDuration']) -and $resolved.PSObject.Properties['Duration'] -and $resolved.Duration) { try { $resolved | Add-Member -NotePropertyName ActivationDuration -NotePropertyValue $resolved.Duration -Force } catch { $resolved.ActivationDuration = $resolved.Duration }; Write-Verbose "[GroupPolicy][Normalize] Added ActivationDuration from Duration for Group $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)" }

    # 5) Build parameter hashtable for Set-PIMGroupPolicy and normalize array-typed inputs
    #    - ActivationRequirement / ActiveAssignmentRequirement accept string[]; also accept comma-delimited string and split it.
    $setParams = @{ tenantID=$TenantId; groupID=@($PolicyDefinition.GroupId); type=$PolicyDefinition.RoleName.ToLower() }
    $suppressedAuthCtx = $false
    foreach ($prop in $resolved.PSObject.Properties) {
        switch ($prop.Name) {
            'ActivationDuration' { if ($prop.Value) { $setParams.ActivationDuration = $prop.Value } }
            'ActivationRequirement' {
                if ($null -ne $prop.Value) {
                    $val = $prop.Value
                    if ($val -is [string]) { if ($val -match ',') { $val = ($val -split ',') | ForEach-Object { $_.ToString().Trim() } } else { $val = @($val) } }
                    elseif (-not ($val -is [System.Collections.IEnumerable])) { $val = @($val) }
                    $setParams.ActivationRequirement = $val
                }
            }
            'ActiveAssignmentRequirement' {
                if ($null -ne $prop.Value) {
                    $val = $prop.Value
                    if ($val -is [string]) { if ($val -match ',') { $val = ($val -split ',') | ForEach-Object { $_.ToString().Trim() } } else { $val = @($val) } }
                    elseif (-not ($val -is [System.Collections.IEnumerable])) { $val = @($val) }
                    $setParams.ActiveAssignmentRequirement = $val
                }
            }
            # 6) Authentication Context not supported for Group roleManagementPolicies; ignore if present
            #    This prevents Graph InvalidPolicy on Group policies while leaving Entra role policies unaffected.
            'AuthenticationContext_Enabled' { $suppressedAuthCtx = $true; continue }
            'AuthenticationContext_Value' { $suppressedAuthCtx = $true; continue }
            'ApprovalRequired' { $setParams.ApprovalRequired = $prop.Value }
            'Approvers' { $setParams.Approvers = $prop.Value }
            'MaximumEligibilityDuration' { $setParams.MaximumEligibilityDuration = $prop.Value }
            'AllowPermanentEligibility' { $setParams.AllowPermanentEligibility = $prop.Value }
            'MaximumActiveAssignmentDuration' { $setParams.MaximumActiveAssignmentDuration = $prop.Value }
            'AllowPermanentActiveAssignment' { $setParams.AllowPermanentActiveAssignment = $prop.Value }
            default {
                # Pass through any normalized Notification_* hashtable parameters to Set-PIMGroupPolicy
                if ($prop.Name -like 'Notification_*') { $setParams[$prop.Name] = $prop.Value }
            }
        }
    }
    if ($suppressedAuthCtx) { Write-Verbose "[GroupPolicy][Normalize] AuthenticationContext_* provided but not supported for Groups; ignoring for Group $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)" }

    # 7) Apply the policy via Set-PIMGroupPolicy with a compact parameter preview for diagnostics
    $status = 'Applied'
    if ($PSCmdlet.ShouldProcess("Group policy for $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)", "Apply policy")) {
        if (Get-Command -Name Set-PIMGroupPolicy -ErrorAction SilentlyContinue) {
            try { Write-Verbose ("[Policy][Group] Calling Set-PIMGroupPolicy with params: " + (($setParams.GetEnumerator() | ForEach-Object { $_.Key + '=' + ($_.Value -join ',') }) -join ' ')); Set-PIMGroupPolicy @setParams -Verbose:$VerbosePreference | Out-Null }
            catch { Write-Warning "Set-PIMGroupPolicy failed: $($_.Exception.Message)"; $status='Failed' }
        } else { Write-Warning 'Set-PIMGroupPolicy cmdlet not found.'; $status='CmdletMissing' }
    } else { $status='Skipped' }

    return @{ GroupId = $PolicyDefinition.GroupId; RoleName = $PolicyDefinition.RoleName; Status = $status; Mode = $Mode }
}
