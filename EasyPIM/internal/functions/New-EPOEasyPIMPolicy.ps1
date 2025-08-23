#Requires -Version 5.1

<#
.SYNOPSIS
Convenience wrapper to process policies using a singular noun form.

.DESCRIPTION
Delegates to New-EPOEasyPIMPolicies to apply or validate policies based on the provided configuration, mode, and targets.

.PARAMETER Config
The PSCustomObject configuration object containing policy definitions.

.PARAMETER TenantId
The target Entra tenant ID.

.PARAMETER SubscriptionId
The Azure subscription ID for Azure role policies.

.PARAMETER PolicyMode
Policy apply mode: validate, delta, initial.

.EXAMPLE
New-EPOEasyPIMPolicy -Config $cfg -TenantId $tid -SubscriptionId $sub -PolicyMode delta
Returns the same result object as New-EPOEasyPIMPolicies.

.NOTES
Provided for naming consistency; returns the result from New-EPOEasyPIMPolicies.
#>
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
