#Requires -Version 5.1

function Set-EPOGroupPolicy {
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

    if (-not $PolicyDefinition.GroupId -and $PolicyDefinition.GroupName) {
        try { $endpoint = "groups?`$filter=displayName eq '$($PolicyDefinition.GroupName)'"; $resp = invoke-graph -Endpoint $endpoint; if ($resp.value -and $resp.value.Count -ge 1) { $PolicyDefinition | Add-Member -NotePropertyName GroupId -NotePropertyValue $resp.value[0].id -Force } else { throw "Unable to resolve GroupName '$($PolicyDefinition.GroupName)' to an Id" } } catch { Write-Warning "GroupName resolution failed: $($_.Exception.Message)" }
    }
    $groupRef = if ($PolicyDefinition.GroupId) { $PolicyDefinition.GroupId } else { $PolicyDefinition.GroupName }
    Write-Verbose "Applying Group policy for Group $groupRef role $($PolicyDefinition.RoleName)"

    if ($Mode -ne 'validate' -and -not $SkipEligibilityCheck) {
        if (-not $PolicyDefinition.GroupId) { Write-Warning "Cannot check eligibility without GroupId for group name '$($PolicyDefinition.GroupName)'" }
        else { $eligible = $true; try { $eligible = Test-GroupEligibleForPIM -GroupId $PolicyDefinition.GroupId } catch { Write-Verbose "Eligibility check failed: $($_.Exception.Message)" }; if (-not $eligible) { if (-not $script:EasyPIM_DeferredGroupPolicies) { $script:EasyPIM_DeferredGroupPolicies = @() }; $script:EasyPIM_DeferredGroupPolicies += [PSCustomObject]@{ GroupId=$PolicyDefinition.GroupId; GroupName=$PolicyDefinition.GroupName; RoleName=$PolicyDefinition.RoleName; ResolvedPolicy=$PolicyDefinition.ResolvedPolicy; OriginalPolicy=$PolicyDefinition }; Write-Warning "Deferring Group policy for $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName) - group not PIM-eligible yet"; return @{ GroupId = $PolicyDefinition.GroupId; RoleName = $PolicyDefinition.RoleName; Status = 'DeferredNotEligible'; Mode = $Mode } } }
    }

    if ($Mode -eq "validate") { $groupRefValidate = if ($PolicyDefinition.GroupId) { $PolicyDefinition.GroupId } else { $PolicyDefinition.GroupName }; Write-Verbose "Validation mode: Policy would be applied for Group '$groupRefValidate' role '$($PolicyDefinition.RoleName)'"; return @{ GroupId = $PolicyDefinition.GroupId; RoleName = $PolicyDefinition.RoleName; Status = 'Validated'; Mode = $Mode } }

    $resolved = if ($PolicyDefinition.ResolvedPolicy) { $PolicyDefinition.ResolvedPolicy } else { $PolicyDefinition }
    if (-not ($resolved.PSObject.Properties['ActivationRequirement']) -and $resolved.PSObject.Properties['EnablementRules'] -and $resolved.EnablementRules) { try { $resolved | Add-Member -NotePropertyName ActivationRequirement -NotePropertyValue $resolved.EnablementRules -Force } catch { $resolved.ActivationRequirement = $resolved.EnablementRules }; Write-Verbose "[GroupPolicy][Normalize] Added ActivationRequirement from EnablementRules for Group $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)" }
    if (-not ($resolved.PSObject.Properties['ActivationDuration']) -and $resolved.PSObject.Properties['Duration'] -and $resolved.Duration) { try { $resolved | Add-Member -NotePropertyName ActivationDuration -NotePropertyValue $resolved.Duration -Force } catch { $resolved.ActivationDuration = $resolved.Duration }; Write-Verbose "[GroupPolicy][Normalize] Added ActivationDuration from Duration for Group $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)" }

    $setParams = @{ tenantID=$TenantId; groupID=@($PolicyDefinition.GroupId); type=$PolicyDefinition.RoleName.ToLower() }
    foreach ($prop in $resolved.PSObject.Properties) {
        switch ($prop.Name) {
            'ActivationDuration' { if ($prop.Value) { $setParams.ActivationDuration = $prop.Value } }
            'ActivationRequirement' { if ($prop.Value) { $setParams.ActivationRequirement = $prop.Value } }
            'ActiveAssignmentRequirement' { if ($prop.Value) { $setParams.ActiveAssignmentRequirement = $prop.Value } }
            'AuthenticationContext_Enabled' { $setParams.AuthenticationContext_Enabled = $prop.Value }
            'AuthenticationContext_Value' { $setParams.AuthenticationContext_Value = $prop.Value }
            'ApprovalRequired' { $setParams.ApprovalRequired = $prop.Value }
            'Approvers' { $setParams.Approvers = $prop.Value }
            'MaximumEligibilityDuration' { $setParams.MaximumEligibilityDuration = $prop.Value }
            'AllowPermanentEligibility' { $setParams.AllowPermanentEligibility = $prop.Value }
            'MaximumActiveAssignmentDuration' { $setParams.MaximumActiveAssignmentDuration = $prop.Value }
            'AllowPermanentActiveAssignment' { $setParams.AllowPermanentActiveAssignment = $prop.Value }
            default { if ($prop.Name -like 'Notification_*') { $setParams[$prop.Name] = $prop.Value } }
        }
    }

    $status = 'Applied'
    if ($PSCmdlet.ShouldProcess("Group policy for $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)", "Apply policy")) {
        if (Get-Command -Name Set-PIMGroupPolicy -ErrorAction SilentlyContinue) {
            try { Write-Verbose ("[Policy][Group] Calling Set-PIMGroupPolicy with params: " + (($setParams.GetEnumerator() | ForEach-Object { $_.Key + '=' + ($_.Value -join ',') }) -join ' ')); Set-PIMGroupPolicy @setParams -Verbose:$VerbosePreference | Out-Null }
            catch { Write-Warning "Set-PIMGroupPolicy failed: $($_.Exception.Message)"; $status='Failed' }
        } else { Write-Warning 'Set-PIMGroupPolicy cmdlet not found.'; $status='CmdletMissing' }
    } else { $status='Skipped' }

    return @{ GroupId = $PolicyDefinition.GroupId; RoleName = $PolicyDefinition.RoleName; Status = $status; Mode = $Mode }
}
