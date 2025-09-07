# Load orchestrator's internal functions
foreach ($file in Get-ChildItem -Path "$PSScriptRoot/internal/functions" -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue) {
    . $file.FullName
}

# Load orchestrator's public functions
foreach ($file in Get-ChildItem -Path "$PSScriptRoot/functions" -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue) {
    . $file.FullName
}

# Export only the public entrypoints
Export-ModuleMember -Function @(
	'Invoke-EasyPIMOrchestrator',
	'Test-PIMPolicyDrift',
	'Test-PIMEndpointDiscovery',
	'Disable-EasyPIMTelemetry'
)
