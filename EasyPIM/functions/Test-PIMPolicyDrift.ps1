function Test-PIMPolicyDrift {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPositionalParameters", "")]
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$ConfigPath,
        [string]$SubscriptionId,
        [switch]$FailOnDrift,
        [switch]$PassThru
    )

    # Ensure orchestrator module is available
    $loaded = Get-Module -Name EasyPIM.Orchestrator
    if (-not $loaded) {
        $root = Split-Path -Path $PSScriptRoot -Parent
        $orchestratorDir = Join-Path -Path $root -ChildPath 'EasyPIM.Orchestrator'
        $orchestratorManifest = Join-Path -Path $orchestratorDir -ChildPath 'EasyPIM.Orchestrator.psd1'
        if (Test-Path -Path $orchestratorManifest) {
            Import-Module -Name $orchestratorManifest -Force
        }
        else {
            Import-Module -Name EasyPIM.Orchestrator -ErrorAction SilentlyContinue
        }
    }

    & EasyPIM.Orchestrator\Test-PIMPolicyDrift @PSBoundParameters
}
