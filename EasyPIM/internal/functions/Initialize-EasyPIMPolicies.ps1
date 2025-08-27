#Requires -Version 5.1

# PSScriptAnalyzer suppressions for this internal policy orchestration file
# The "Policies" plural naming is intentional as it initializes multiple policies collectively

function Initialize-EasyPIMPolicies {
    <#
    .SYNOPSIS
        Forwards to the shared version of Initialize-EasyPIMPolicies.

    .DESCRIPTION
        This function is a stub that forwards calls to the shared version in EasyPIM.Shared.
        The actual implementation is in the shared module to avoid code duplication.

    .PARAMETER Config
        The configuration object containing policy definitions

    .PARAMETER PolicyOperations
        Which policy operations to process

    .EXAMPLE
        $processedPolicies = Initialize-EasyPIMPolicies -Config $config

    .NOTES
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $false)]
        [ValidateSet("All", "AzureRoles", "EntraRoles", "GroupRoles")]
        [string[]]$PolicyOperations = @("All")
    )

    Write-Verbose '[Core->Shared] Initialize-EasyPIMPolicies is shared-owned. Forwarding call.'
    try {
        return EasyPIM.Shared\Initialize-EasyPIMPolicies -Config $Config -PolicyOperations $PolicyOperations
    } catch {
        throw "Initialize-EasyPIMPolicies is now provided by EasyPIM.Shared. Please import EasyPIM.Shared or use EasyPIM.Orchestrator which loads it automatically. Details: $($_.Exception.Message)"
    }
}
