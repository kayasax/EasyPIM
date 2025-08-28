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
}

# NOTE: EasyPIM core module is now automatically loaded via RequiredModules in manifest
# However, in local development, we want to ensure the LOCAL version is loaded, not Gallery version

# Detect if we're running in local development environment
$isLocalDevelopment = $PSScriptRoot -and 
    ($PSScriptRoot -like "*\EasyPIM*" -or $PSScriptRoot -like "*EasyPIM*")

if ($isLocalDevelopment) {
    # In local development, check if we got the local version or Gallery version
    $loadedEasyPIM = Get-Module -Name EasyPIM -ErrorAction SilentlyContinue
    if ($loadedEasyPIM -and $loadedEasyPIM.ModuleBase -notlike "*$PSScriptRoot*") {
        Write-Verbose "Gallery EasyPIM loaded in dev environment, attempting to load local version..."
        
        # Try to load local version instead
        $localCandidates = @(
            (Join-Path (Split-Path -Parent $PSScriptRoot) 'EasyPIM/EasyPIM.psd1'),
            (Join-Path $PSScriptRoot '../EasyPIM/EasyPIM.psd1')
        )
        
        foreach ($cand in $localCandidates) {
            if (Test-Path $cand) {
                try {
                    Remove-Module EasyPIM -Force -ErrorAction SilentlyContinue
                    $absolutePath = (Resolve-Path $cand).Path
                    Write-Verbose "Loading local EasyPIM from: $absolutePath"
                    Import-Module $absolutePath -Force -Global -ErrorAction Stop
                    Write-Verbose "Successfully loaded local EasyPIM core module for development"
                    break
                } catch {
                    Write-Warning "Could not load local EasyPIM: $($_.Exception.Message)"
                    # Reload the Gallery version if local fails
                    Import-Module EasyPIM -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
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
