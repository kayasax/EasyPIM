
# Ensure private shared helpers are available (Write-SectionHeader, Initialize-EasyPIMAssignments, etc.)
# Try packaged relative path first (used after build), then repo-relative for local dev.
$sharedCandidates = @(
	(Join-Path $PSScriptRoot 'shared/EasyPIM.Shared/EasyPIM.Shared.psd1'),
	(Join-Path (Split-Path -Parent $PSScriptRoot) 'shared/EasyPIM.Shared/EasyPIM.Shared.psd1')
)
foreach ($cand in $sharedCandidates) {
	if (Test-Path $cand) {
		try { Import-Module $cand -Scope Local -ErrorAction Stop | Out-Null } catch {}
		break
	}
}

# Dot-source existing orchestrator functions from the EasyPIM repository tree and export public entrypoints.

$root = Split-Path -Parent $PSScriptRoot
$easyPIMDir = Join-Path $root 'EasyPIM'

# Source public orchestrator functions locally from this module
$localFunctionFiles = @(
	(Join-Path $PSScriptRoot 'functions/Invoke-EasyPIMOrchestrator.ps1'),
	(Join-Path $PSScriptRoot 'functions/Test-PIMPolicyDrift.ps1'),
	(Join-Path $PSScriptRoot 'functions/Test-PIMEndpointDiscovery.ps1')
)
foreach ($f in $localFunctionFiles) { if (Test-Path $f) { . $f } }


# Load this module's own internal helpers
foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'internal/functions') -Filter *.ps1 -Recurse) {
	. $file.FullName
}

# Export only the public entrypoints
Export-ModuleMember -Function @(
	'Invoke-EasyPIMOrchestrator',
	'Test-PIMPolicyDrift',
	'Test-PIMEndpointDiscovery'
)
