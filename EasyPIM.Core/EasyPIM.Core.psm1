# EasyPIM.Core (Phase 1): re-export a minimal set of read-only helpers by dot-sourcing existing files.
# Non-breaking: main EasyPIM module remains the primary entry point.

$root = Split-Path -Parent $PSScriptRoot
$easyPIMDir = Join-Path $root 'EasyPIM'

# Core/read-only helpers (initial subset)
$coreFiles = @(
	'functions/Test-PIMEndpointDiscovery.ps1',
	'internal/functions/Get-PIMAzureEnvironmentEndpoint.ps1',
	'internal/functions/Get-RoleMappings.ps1'
)

foreach ($rel in $coreFiles) {
	$path = Join-Path $easyPIMDir $rel
	if (Test-Path $path) { . $path }
}

Export-ModuleMember -Function @(
	'Test-PIMEndpointDiscovery',
	'Get-PIMAzureEnvironmentEndpoint',
	'Get-RoleMappings'
)
