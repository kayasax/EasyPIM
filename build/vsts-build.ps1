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
# Join with consistent line endings and write with UTF8 encoding
$combinedContent = $text -join "`r`n`r`n"
[System.IO.File]::WriteAllText("$($publishDir.FullName)\EasyPIM\EasyPIM.psm1", $combinedContent, [System.Text.UTF8Encoding]::new($false))
Remove-Item -Path "$($publishDir.FullName)\EasyPIM\internal" -Recurse -Force
Remove-Item -Path "$($publishDir.FullName)\EasyPIM\functions" -Recurse -Force
#endregion Update the psm1 file & Cleanup

#region Test Module Import
Write-Host "Testing module import to catch any syntax errors..."
try {
    # Import the module to validate it loads correctly
    Import-Module -Name "$($publishDir.FullName)\EasyPIM\EasyPIM.psd1" -Force -ErrorAction Stop
    Write-Host "Module imported successfully!" -ForegroundColor Green
    # Optional: List commands to further validate
    #Get-Command -Module EasyPIM | Select-Object -First 5 | Format-Table -AutoSize
    # Remove the module after testing
    Remove-Module -Name EasyPIM -ErrorAction SilentlyContinue
} catch {
    Write-Host "ERROR: Module failed to import. Details:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    throw "Module validation failed. Please check the error message above."
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
