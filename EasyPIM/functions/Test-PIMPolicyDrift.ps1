function Test-PIMPolicyDrift {
    [CmdletBinding()]
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
        $orchestratorManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'EasyPIM.Orchestrator' 'EasyPIM.Orchestrator.psd1'
        if (Test-Path $orchestratorManifest) { Import-Module $orchestratorManifest -Force } else { Import-Module EasyPIM.Orchestrator -ErrorAction SilentlyContinue }
    }

    & EasyPIM.Orchestrator\Test-PIMPolicyDrift @PSBoundParameters
}
