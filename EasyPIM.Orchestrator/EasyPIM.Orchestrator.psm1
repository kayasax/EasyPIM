# Suppress verbose noise during import; restore afterwards
$__easypim_vp = $VerbosePreference
try {
	$VerbosePreference = 'SilentlyContinue'

# Load orchestrator's own internal helper functions (simple duplication approach)
$internalPaths = @(
    (Join-Path $PSScriptRoot 'internal'),
    (Join-Path $PSScriptRoot 'internal/functions')
)

foreach ($internalPath in $internalPaths) {
    if (Test-Path $internalPath) {
        foreach ($file in Get-ChildItem -Path $internalPath -Filter *.ps1 -Recurse) {
            . $file.FullName
        }
    }
}# Import EasyPIM core module - REQUIRED for orchestrator functions to work
$coreImportSuccess = $false
try {
	# Try local EasyPIM core module paths for development
	$easyPIMCandidates = @(
		(Join-Path (Split-Path -Parent $PSScriptRoot) 'EasyPIM/EasyPIM.psd1'),
		(Join-Path $PSScriptRoot '../EasyPIM/EasyPIM.psd1')
	)

	foreach ($cand in $easyPIMCandidates) {
		if (Test-Path $cand) {
			Write-Verbose "Importing local EasyPIM core module from: $cand"
			Import-Module $cand -Force -ErrorAction Stop
			$coreImportSuccess = $true
			Write-Verbose "Successfully imported local EasyPIM core module"
			break
		}
	}

	# If local module not found, try installed EasyPIM from Gallery
	if (-not $coreImportSuccess) {
		Write-Verbose "Local EasyPIM not found, trying installed/Gallery module..."
		try {
			Import-Module 'EasyPIM' -Force -ErrorAction Stop
			$coreImportSuccess = $true
			Write-Verbose "Successfully imported EasyPIM module from Gallery/installed location"
		} catch {
			Write-Warning "Could not import EasyPIM module locally or from Gallery: $($_.Exception.Message)"
		}
	}
} catch {
	Write-Warning "Failed to import EasyPIM core module: $($_.Exception.Message). Orchestrator functions may not work correctly."
}

# Version check - only when not in local development
# Completely disabled when importing from local paths to avoid Gallery noise
$isLocalDevelopment = $MyInvocation.MyCommand.Path -and
    (Split-Path $MyInvocation.MyCommand.Path -Parent) -like "*\EasyPIM*"

if (-not $isLocalDevelopment -and -not $env:EASYPIM_NO_VERSION_CHECK) {
	try {
		# Only check versions when running from installed module location
		$latestInfo = Find-Module -Name 'EasyPIM.Orchestrator' -AllowPrerelease -ErrorAction Stop
		$currentVersion = $MyInvocation.MyCommand.Module.Version

		if ($currentVersion -lt [version]$latestInfo.Version) {
			Write-Host "💡 EasyPIM.Orchestrator update available: $($latestInfo.Version)" -ForegroundColor Cyan
		}
	} catch {
		# Silently continue if version check fails (no internet, etc.)
		Write-Verbose "Version check skipped: $($_.Exception.Message)"
	}
}

# Dot-source orchestrator functions

# Source public orchestrator functions locally from this module
$localFunctionFiles = @(
	(Join-Path $PSScriptRoot 'functions/Invoke-EasyPIMOrchestrator.ps1'),
	(Join-Path $PSScriptRoot 'functions/Test-PIMPolicyDrift.ps1'),
	(Join-Path $PSScriptRoot 'functions/Test-PIMEndpointDiscovery.ps1')
)
foreach ($f in $localFunctionFiles) { if (Test-Path $f) { . $f } }


# NOTE: Internal functions are already loaded above

# Export only the public entrypoints
Export-ModuleMember -Function @(
	'Invoke-EasyPIMOrchestrator',
	'Test-PIMPolicyDrift',
	'Test-PIMEndpointDiscovery'
)

} finally {
	$VerbosePreference = $__easypim_vp
}
