#Requires -Version 5.1

function Invoke-EPODeferredGroupPolicies {
    <#
    .SYNOPSIS
    Applies any group policies that were deferred earlier in the run.

    .DESCRIPTION
    Some group policies are deferred when the group isn't yet PIM-eligible. This command
    re-attempts those policies using the provided TenantId and Mode.

    .PARAMETER TenantId
    The Entra tenant ID used to connect and apply the group policies.

    .PARAMETER Mode
    Policy application mode: validate, delta, or initial. Defaults to delta.

    .EXAMPLE
    Invoke-EPODeferredGroupPolicies -TenantId $tenant -Mode delta
    Replays deferred group policies with delta semantics (additive changes).

    .EXAMPLE
    Invoke-EPODeferredGroupPolicies -TenantId $tenant -Mode validate
    Attempts policies in validation mode; no changes are made.

    .NOTES
    Uses Set-EPOGroupPolicy internally and clears the deferred queue upon completion.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        [Parameter(Mandatory = $false)]
        [ValidateSet('validate','delta','initial')]
        [string]$Mode = 'delta'
    )

    if (-not $script:EasyPIM_DeferredGroupPolicies -or $script:EasyPIM_DeferredGroupPolicies.Count -eq 0) {
        Write-Verbose "No deferred group policies to process."
        return @{ Attempted = 0; Applied = 0; Failed = 0; Skipped = 0 }
    }

    $attempted = 0; $applied = 0; $failed = 0; $skipped = 0
    foreach ($policyDef in @($script:EasyPIM_DeferredGroupPolicies)) {
        $attempted++
        try {
            $res = Set-EPOGroupPolicy -PolicyDefinition $policyDef -TenantId $TenantId -Mode $Mode -SkipEligibilityCheck -WhatIf:$WhatIfPreference
            switch ($res.Status) {
                'Applied' { $applied++ }
                'Failed' { $failed++ }
                default { $skipped++ }
            }
        } catch {
            Write-Warning "Deferred group policy apply failed for Group $($policyDef.GroupId): $($_.Exception.Message)"
            $failed++
        }
    }

    # Clear after attempt
    $script:EasyPIM_DeferredGroupPolicies = @()

    return @{ Attempted = $attempted; Applied = $applied; Failed = $failed; Skipped = $skipped }
}
