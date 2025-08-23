# EasyPIM.Orchestrator (Phase 1)
# Dot-source existing orchestrator functions from the EasyPIM repository tree and export public entrypoints.

$root = Split-Path -Parent $PSScriptRoot
$easyPIMDir = Join-Path $root 'EasyPIM'

$orchestratorFiles = @(
	'functions/Invoke-EasyPIMOrchestrator.ps1',
	'internal/functions/New-EPOEasyPIMPolicies.ps1',
	'internal/functions/New-EPOEasyPIMPolicy.ps1',
	'internal/functions/Set-EPOAzureRolePolicy.ps1',
	'internal/functions/Set-EPOEntraRolePolicy.ps1',
	'internal/functions/Set-EPOGroupPolicy.ps1',
	'internal/functions/Invoke-EPODeferredGroupPolicies.ps1',
	# Internals required by orchestrator but not exported
	'internal/functions/EPO_Write-EasyPIMSummary.ps1'
)

foreach ($rel in $orchestratorFiles) {
	$path = Join-Path $easyPIMDir $rel
	if (Test-Path $path) { . $path }
}

# Export only the public entrypoints
Export-ModuleMember -Function @(
	'Invoke-EasyPIMOrchestrator',
	'New-EPOEasyPIMPolicies',
	'New-EPOEasyPIMPolicy',
	'Set-EPOAzureRolePolicy',
	'Set-EPOEntraRolePolicy',
	'Set-EPOGroupPolicy',
	'Invoke-EPODeferredGroupPolicies'
)
