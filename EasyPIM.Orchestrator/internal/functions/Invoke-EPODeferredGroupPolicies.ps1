#Requires -Version 5.1

function Invoke-EPODeferredGroupPolicies {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        [Parameter(Mandatory = $false)]
        [ValidateSet('delta','initial')]
        [string]$Mode = 'delta'
    )

    if (-not $script:EasyPIM_DeferredGroupPolicies -or $script:EasyPIM_DeferredGroupPolicies.Count -eq 0) {
        Write-Verbose "No deferred group policies to process."
        return @{ Attempted = 0; Applied = 0; Failed = 0; Skipped = 0 }
    }

    $attempted = 0; $applied = 0; $failed = 0; $skipped = 0
    foreach ($policyDef in @($script:EasyPIM_DeferredGroupPolicies)) {
        $attempted++
        $target = "Group $($policyDef.GroupId) role $($policyDef.RoleName)"
        if ($PSCmdlet.ShouldProcess($target, "Apply deferred group policy")) {
            try {
                $res = Set-EPOGroupPolicy -PolicyDefinition $policyDef -TenantId $TenantId -Mode $Mode -SkipEligibilityCheck -WhatIf:$WhatIfPreference
                switch ($res.Status) {
                    'Applied' { $applied++ }
                    'Failed' { $failed++ }
                    default { $skipped++ }
                }
            } catch {
                Write-Warning "Deferred group policy apply failed for $($target): $($_.Exception.Message)"
                $failed++
            }
        } else {
            $skipped++
        }
    }

    # Clear after attempt
    $script:EasyPIM_DeferredGroupPolicies = @()

    return @{ Attempted = $attempted; Applied = $applied; Failed = $failed; Skipped = $skipped }
}
