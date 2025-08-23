function Invoke-EasyPIMOrchestrator {
    [CmdletBinding(DefaultParameterSetName = 'Default', SupportsShouldProcess = $true, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')][string]$KeyVaultName,
        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')][string]$SecretName,
        [string]$SubscriptionId,
        [Parameter(Mandatory = $true, ParameterSetName = 'FilePath')][string]$ConfigFilePath,
        [ValidateSet('initial','delta')][string]$Mode = 'delta',
        [string]$TenantId,
        [ValidateSet('All','AzureRoles','EntraRoles','GroupRoles')][string[]]$Operations = @('All'),
        [switch]$SkipAssignments,
        [switch]$SkipCleanup,
        [switch]$SkipPolicies,
        [ValidateSet('All','AzureRoles','EntraRoles','GroupRoles')][string[]]$PolicyOperations = @('All'),
        [string]$WouldRemoveExportPath
    )

    # Ensure orchestrator module is available
    $loaded = Get-Module -Name EasyPIM.Orchestrator
    if (-not $loaded) {
        $orchestratorManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'EasyPIM.Orchestrator' 'EasyPIM.Orchestrator.psd1'
        if (Test-Path $orchestratorManifest) { Import-Module $orchestratorManifest -Force } else { Import-Module EasyPIM.Orchestrator -ErrorAction SilentlyContinue }
    }

    & EasyPIM.Orchestrator\Invoke-EasyPIMOrchestrator @PSBoundParameters
}