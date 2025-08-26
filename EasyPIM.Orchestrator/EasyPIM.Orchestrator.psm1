# Suppress verbose noise during import; restore afterwards
$__easypim_vp = $VerbosePreference
try {
	$VerbosePreference = 'SilentlyContinue'

# Ensure private shared helpers are available (Write-SectionHeader, Initialize-EasyPIMAssignments, etc.)
# Try packaged relative path first (used after build), then repo-relative for local dev.
$sharedCandidates = @(
	(Join-Path (Split-Path -Parent $PSScriptRoot) 'shared/EasyPIM.Shared/EasyPIM.Shared.psd1'),
	(Join-Path $PSScriptRoot 'shared/EasyPIM.Shared/EasyPIM.Shared.psd1')
)
foreach ($cand in $sharedCandidates) {
	if (Test-Path $cand) {
		try {
			if (Get-Module -Name 'EasyPIM.Shared' -ErrorAction SilentlyContinue) { Remove-Module -Name 'EasyPIM.Shared' -Force -ErrorAction SilentlyContinue }
			Import-Module $cand -Force -ErrorAction Stop | Out-Null
		} catch {}
		break
	}
}

# Prefer local EasyPIM core module when present so orchestrator uses in-repo functions
try {
	if (Get-Module -Name 'EasyPIM' -ErrorAction SilentlyContinue) { Remove-Module -Name 'EasyPIM' -Force -ErrorAction SilentlyContinue }
	$easyPIMCandidates = @(
		(Join-Path (Split-Path -Parent $PSScriptRoot) 'EasyPIM/EasyPIM.psd1'),
		(Join-Path $PSScriptRoot '../EasyPIM/EasyPIM.psd1')
	)
	foreach ($cand in $easyPIMCandidates) {
		if (Test-Path $cand) { Import-Module $cand -Force -ErrorAction Stop | Out-Null; break }
	}
} catch { Write-Verbose "EasyPIM core import skipped: $($_.Exception.Message)" }

# Version check (opt-out with EASYPIM_NO_VERSION_CHECK=1)
if (-not $env:EASYPIM_NO_VERSION_CHECK) {
	try {
		# Determine currently loaded/available version (works in dev import too)
		$currentVersion = $null
		try { $currentVersion = [string]$MyInvocation.MyCommand.Module.Version } catch {}
		if (-not $currentVersion) {
			$installed = Get-Module -ListAvailable 'EasyPIM.Orchestrator' | Sort-Object Version -Descending | Select-Object -First 1
			if ($installed) { $currentVersion = [string]$installed.Version }
		}
		if (-not $currentVersion) { $currentVersion = '0.0.0' }
		Write-Verbose "EasyPIM.Orchestrator installed version: $currentVersion"

		$latestInfo = Find-Module -Name 'EasyPIM.Orchestrator' -AllowPrerelease -ErrorAction Stop
		$latestVersion = [string]$latestInfo.Version
		Write-Verbose "EasyPIM.Orchestrator latest version: $latestVersion (Prerelease: $($latestInfo.Prerelease))"

		$showNotice = $false
		try {
			$cv = [version]$currentVersion
			$lv = [version]$latestVersion
			if ($cv -lt $lv) { $showNotice = $true }
		} catch {
			# Fallback for semantic/prerelease version strings: notify if strings differ
			if ($currentVersion -ne $latestVersion) { $showNotice = $true }
		}

		if ($showNotice) {
			Write-Host "🔥 FYI: A newer version of EasyPIM.Orchestrator is available! Run the command below to update to the latest version."
			Write-Host "💥 Installed version: $currentVersion → Latest version: $latestVersion" -ForegroundColor DarkGray
			$allowPre = if ($latestInfo.Prerelease) { ' -AllowPrerelease' } else { '' }
			Write-Host "✨ Update-Module EasyPIM.Orchestrator$allowPre" -NoNewline -ForegroundColor Green
			Write-Host " → Install the latest version of EasyPIM.Orchestrator." -ForegroundColor Yellow
		}
	}
	catch { Write-Verbose "Version check skipped: $($_.Exception.Message)" }
}

# Dot-source existing orchestrator functions from the EasyPIM repository tree and export public entrypoints.

$root = Split-Path -Parent $PSScriptRoot

# Source public orchestrator functions locally from this module
$localFunctionFiles = @(
	(Join-Path $PSScriptRoot 'functions/Invoke-EasyPIMOrchestrator.ps1'),
	(Join-Path $PSScriptRoot 'functions/Test-PIMPolicyDrift.ps1'),
	(Join-Path $PSScriptRoot 'functions/Test-PIMEndpointDiscovery.ps1')
)
foreach ($f in $localFunctionFiles) { if (Test-Path $f) { . $f } }


# Load this module's own internal helpers (kept private)
foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'internal/functions') -Filter *.ps1 -Recurse) {
	. $file.FullName
}

# Export only the public entrypoints
Export-ModuleMember -Function @(
	'Invoke-EasyPIMOrchestrator',
	'Test-PIMPolicyDrift',
	'Test-PIMEndpointDiscovery'
)

} finally {
	$VerbosePreference = $__easypim_vp
}
