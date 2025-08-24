function Invoke-EasyPIMOrchestrator {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPositionalParameters", "")]
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

    return EasyPIM.Orchestrator\Invoke-EasyPIMOrchestrator @PSBoundParameters
}