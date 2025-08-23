# EasyPIM.Orchestrator (Phase 1)
# Dot-source existing orchestrator functions from the EasyPIM repository tree and export public entrypoints.

$root = Split-Path -Parent $PSScriptRoot
$easyPIMDir = Join-Path $root 'EasyPIM'

# Source public orchestrator functions locally from this module
$localFunctionFiles = @(
	(Join-Path $PSScriptRoot 'functions/Invoke-EasyPIMOrchestrator.ps1'),
	(Join-Path $PSScriptRoot 'functions/Test-PIMPolicyDrift.ps1')
)
foreach ($f in $localFunctionFiles) { if (Test-Path $f) { . $f } }

# Source required internal helper from EasyPIM core (kept internal for now)
$easyPIMInternalFiles = @(
	'internal/functions/EPO_Write-EasyPIMSummary.ps1'
)
foreach ($rel in $easyPIMInternalFiles) {
	$path = Join-Path $easyPIMDir $rel
	if (Test-Path $path) { . $path }
}

# Export only the public entrypoints
Export-ModuleMember -Function @(
	'Invoke-EasyPIMOrchestrator',
	'Test-PIMPolicyDrift'
)
