#Requires -Version 5.1

function New-EPOEasyPIMPolicy {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory=$true)]
        [string]$TenantId,

        [Parameter(Mandatory=$false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory=$false)]
        [ValidateSet('delta','initial')]
        [string]$PolicyMode = 'delta',

        [Parameter(Mandatory=$false)]
        [switch]$AllowProtectedRoles
    )

    Write-Verbose "[Orchestrator] Delegating to New-EPOEasyPIMPolicies (mode: $PolicyMode)"
    $target = "Tenant $TenantId"
    $null = $PSCmdlet.ShouldProcess($target, "Apply policies")
    return New-EPOEasyPIMPolicies -Config $Config -TenantId $TenantId -SubscriptionId $SubscriptionId -PolicyMode $PolicyMode -AllowProtectedRoles:$AllowProtectedRoles -WhatIf:$WhatIfPreference
}
