# EasyPIM.Orchestrator (Phase 1)
# Dot-source existing orchestrator functions from this module and export public entrypoints.

# Source public orchestrator functions locally from this module
$localFunctionFiles = @(
	(Join-Path $PSScriptRoot 'functions/Invoke-EasyPIMOrchestrator.ps1'),
	(Join-Path $PSScriptRoot 'functions/Test-PIMPolicyDrift.ps1')
)
foreach ($f in $localFunctionFiles) { if (Test-Path $f) { . $f } }

## Do not dot-source across module trees.
## EasyPIM is a RequiredModule; all needed functions (Write-EasyPIMSummary, Initialize-*, New-EPOEasyPIMPolicy, Invoke-EasyPIMCleanup, New-EasyPIMAssignments)
## are exported by EasyPIM and available upon import.

# Export only the public entrypoints
Export-ModuleMember -Function @(
	'Invoke-EasyPIMOrchestrator',
	'Test-PIMPolicyDrift'
)
