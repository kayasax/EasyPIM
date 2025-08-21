#Requires -Version 5.1

# Wrapper to align with PS naming best practices (singular noun)
# Delegates to existing New-EPOEasyPIMPolicies implementation for backward compatibility
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
        [ValidateSet('validate','delta','initial')]
        [string]$PolicyMode = 'validate'
    )

    Write-Verbose "New-EPOEasyPIMPolicy delegating to New-EPOEasyPIMPolicies (mode: $PolicyMode)"
    $target = "Tenant $TenantId"
    # Non-gating ShouldProcess for rich validation output even under -WhatIf
    $null = $PSCmdlet.ShouldProcess($target, "Apply/Validate policies")
    return New-EPOEasyPIMPolicies -Config $Config -TenantId $TenantId -SubscriptionId $SubscriptionId -PolicyMode $PolicyMode -WhatIf:$WhatIfPreference
}
