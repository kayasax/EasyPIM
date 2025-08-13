<#
This script publishes the module to the gallery.
It expects as input an ApiKey authorized to publish the module.

Insert any build steps you may need to take before publishing it here.
#>
param (
	$ApiKey,

	$WorkingDirectory,

	$Repository = 'PSGallery',

	[switch]
	$LocalRepo,

	[switch]
	$SkipPublish,

	[switch]
	$AutoVersion
)

#region Handle Working Directory Defaults
if (-not $WorkingDirectory)
{
	if ($env:RELEASE_PRIMARYARTIFACTSOURCEALIAS)
	{
		$WorkingDirectory = Join-Path -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -ChildPath $env:RELEASE_PRIMARYARTIFACTSOURCEALIAS
	}
	else { $WorkingDirectory = $env:SYSTEM_DEFAULTWORKINGDIRECTORY }
}
if (-not $WorkingDirectory) { $WorkingDirectory = Split-Path $PSScriptRoot }
#endregion Handle Working Directory Defaults

# Prepare publish folder
Write-Host "Creating and populating publishing directory"
$publishDir = New-Item -Path $WorkingDirectory -Name publish -ItemType Directory -Force
Copy-Item -Path "$($WorkingDirectory)\EasyPIM" -Destination $publishDir.FullName -Recurse -Force

#region Gather text data to compile
$text = @()

# Gather commands
Get-ChildItem -Path "$($publishDir.FullName)\EasyPIM\internal\functions\" -Recurse -File -Filter "*.ps1" | ForEach-Object {
	$content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
	if ($content) {
		# Ensure content ends with a newline to prevent concatenation issues
		if (-not $content.EndsWith("`n") -and -not $content.EndsWith("`r`n")) {
			$content += "`r`n"
		}
		$text += $content
	}
}
Get-ChildItem -Path "$($publishDir.FullName)\EasyPIM\functions\" -Recurse -File -Filter "*.ps1" | ForEach-Object {
	$content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
	if ($content) {
		# Ensure content ends with a newline to prevent concatenation issues
		if (-not $content.EndsWith("`n") -and -not $content.EndsWith("`r`n")) {
			$content += "`r`n"
		}
		$text += $content
	}
}

# Gather scripts
Get-ChildItem -Path "$($publishDir.FullName)\EasyPIM\internal\scripts\" -Recurse -File -Filter "*.ps1" | ForEach-Object {
	$content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
	if ($content) {
		# Ensure content ends with a newline to prevent concatenation issues
		if (-not $content.EndsWith("`n") -and -not $content.EndsWith("`r`n")) {
			$content += "`r`n"
		}
		$text += $content
	}
}

#region Update the psm1 file & Cleanup
# Join with consistent line endings
$combinedContent = $text -join "`r`n`r`n"

Write-Host ("Flatten build collected characters: length={0}" -f $combinedContent.Length)
# Always write UTF8 WITH BOM for Windows PowerShell 5.1 compatibility
$psm1Path = "$($publishDir.FullName)\\EasyPIM\\EasyPIM.psm1"
$utf8BomEncoding = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllText($psm1Path, $combinedContent, $utf8BomEncoding)
Write-Host "Wrote EasyPIM.psm1 as UTF8 with BOM (enforced)" -ForegroundColor Yellow

# Verify BOM presence (EF BB BF)
try {
	$rawBytes = [System.IO.File]::ReadAllBytes($psm1Path)
	$hasBom = ($rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF)
	Write-Host "BOM present: $hasBom" -ForegroundColor DarkCyan
	if (-not $hasBom) {
		Write-Host "WARNING: BOM missing after initial write. Re-writing with BOM..." -ForegroundColor Yellow
		[System.IO.File]::WriteAllText($psm1Path, $combinedContent, $utf8BomEncoding)
		$rawBytes = [System.IO.File]::ReadAllBytes($psm1Path)
		$hasBom = ($rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF)
		if ($hasBom) { Write-Host "BOM successfully repaired." -ForegroundColor Green } else { Write-Host "ERROR: Failed to enforce BOM after retry." -ForegroundColor Red }
	}
}
catch { Write-Host "BOM verification failed: $_" -ForegroundColor Red }
Remove-Item -Path "$($publishDir.FullName)\EasyPIM\internal" -Recurse -Force
Remove-Item -Path "$($publishDir.FullName)\EasyPIM\functions" -Recurse -Force
#endregion Update the psm1 file & Cleanup

#region Test Module Import
Write-Host "Testing module import to catch any syntax errors..."
try {
	Write-Host "PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
	# Static parse validation using PSParser before actual import
	$parseErrors = $null
	$raw = Get-Content "$($publishDir.FullName)\EasyPIM\EasyPIM.psm1" -Raw -ErrorAction Stop
	[System.Management.Automation.PSParser]::Tokenize($raw, [ref]$parseErrors) | Out-Null
	if ($parseErrors -and $parseErrors.Count -gt 0) {
		Write-Host "STATIC PARSE ERRORS DETECTED:" -ForegroundColor Red
		$parseErrors | ForEach-Object { Write-Host ("Line {0}, Col {1}: {2}" -f $_.StartLine, $_.StartColumn, $_.Message) -ForegroundColor Red }
		throw "Static parse validation failed before Import-Module"
	} else {
		Write-Host "Static parse validation passed (no syntax errors)." -ForegroundColor Green
	}

	# Import the module to validate it loads correctly (runtime execution may still throw)
	Import-Module -Name "$($publishDir.FullName)\EasyPIM\EasyPIM.psd1" -Force -ErrorAction Stop -Verbose:($VerbosePreference -eq 'Continue')
	Write-Host "Module imported successfully!" -ForegroundColor Green
	# Optional: Count commands
	$cmdCount = (Get-Command -Module EasyPIM | Measure-Object).Count
	Write-Host "Exported command count: $cmdCount" -ForegroundColor Green
	Remove-Module -Name EasyPIM -ErrorAction SilentlyContinue
} catch {
	Write-Host "ERROR: Module failed to import or validate. Full details:" -ForegroundColor Red
	$_ | Format-List * -Force | Out-String | Write-Host -ForegroundColor Red
	if ($_.ScriptStackTrace) { Write-Host "StackTrace:" -ForegroundColor Red; Write-Host $_.ScriptStackTrace -ForegroundColor Red }
	throw "Module validation failed. See detailed error output above."
}
#endregion Test Module Import

#region Updating the Module Version
if ($AutoVersion)
{
	Write-Host  "Updating module version numbers."
	try { [version]$remoteVersion = (Find-Module 'EasyPIM' -Repository $Repository -ErrorAction Stop).Version }
	catch
	{
		throw "Failed to access $($Repository) : $_"
	}
	if (-not $remoteVersion)
	{
		throw "Couldn't find EasyPIM on repository $($Repository) : $_"
	}
	$newBuildNumber = $remoteVersion.Build + 1
	[version]$localVersion = (Import-PowerShellDataFile -Path "$($publishDir.FullName)\EasyPIM\EasyPIM.psd1").ModuleVersion
	Update-ModuleManifest -Path "$($publishDir.FullName)\EasyPIM\EasyPIM.psd1" -ModuleVersion "$($localVersion.Major).$($localVersion.Minor).$($newBuildNumber)"
}
#endregion Updating the Module Version

#region Publish
if ($SkipPublish) { return }
if ($LocalRepo)
{
	# Dependencies must go first
	Write-Host  "Creating Nuget Package for module: PSFramework"
	New-PSMDModuleNugetPackage -ModulePath (Get-Module -Name PSFramework).ModuleBase -PackagePath .
	Write-Host  "Creating Nuget Package for module: EasyPIM"
	New-PSMDModuleNugetPackage -ModulePath "$($publishDir.FullName)\EasyPIM" -PackagePath .
}
else
{
	# Publish to Gallery
	Write-Host  "Publishing the EasyPIM module to $($Repository)"
	Publish-Module -Path "$($publishDir.FullName)\EasyPIM" -NuGetApiKey $ApiKey -Force -Repository $Repository
}
#endregion Publish
