<#!
This script publishes the EasyPIM.Orchestrator module to the gallery.
It expects as input an ApiKey authorized to publish the module.
#>
param (
    $ApiKey,
    $WorkingDirectory,
    $Repository = 'PSGallery',
    [switch]$LocalRepo,
    [switch]$SkipPublish,
    [switch]$AutoVersion
)

#region Handle Working Directory Defaults
if (-not $WorkingDirectory) {
    $WorkingDirectory = Split-Path $PSScriptRoot
}
#endregion

# Prepare publish folder (use temp to avoid recursive self-copy)
Write-Host "Creating and populating publishing directory"
$publishRoot = if ($env:RUNNER_TEMP) {
    New-Item -Path $env:RUNNER_TEMP -Name ("easypim-orch-publish-" + ([guid]::NewGuid().ToString('N'))) -ItemType Directory -Force
} else {
    New-Item -Path ([System.IO.Path]::GetTempPath()) -Name ("easypim-orch-publish-" + ([guid]::NewGuid().ToString('N'))) -ItemType Directory -Force
}
# Maintain existing variable name semantics: $publishDir points to the publish root
$publishDir = $publishRoot
$moduleOutDir = New-Item -Path $publishDir.FullName -Name 'EasyPIM.Orchestrator' -ItemType Directory -Force

# Copy module contents into publish folder, excluding any existing publish directory
Get-ChildItem -LiteralPath $WorkingDirectory -Force | Where-Object { $_.Name -ne 'publish' } | ForEach-Object {
    $dest = Join-Path $moduleOutDir.FullName $_.Name
    Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force
}
Write-Host ("Publish root: {0}" -f $publishDir.FullName) -ForegroundColor DarkCyan

# Note: Shared module removed in favor of internal function duplication approach
# No longer needed to copy shared module

# Gather commands
$text = @()
Get-ChildItem -Path "$($publishDir.FullName)\EasyPIM.Orchestrator\internal\functions" -Recurse -File -Filter "*.ps1" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        if (-not $content.EndsWith("`n") -and -not $content.EndsWith("`r`n")) {
            $content += "`r`n"
        }
        $text += $content
    }
}
Get-ChildItem -Path "$($publishDir.FullName)\EasyPIM.Orchestrator\functions" -Recurse -File -Filter "*.ps1" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        if (-not $content.EndsWith("`n") -and -not $content.EndsWith("`r`n")) {
            $content += "`r`n"
        }
        $text += $content
    }
}

# Join with consistent line endings
$combinedContent = $text -join "`r`n`r`n"

Write-Host ("Flatten build collected characters: length={0}" -f $combinedContent.Length)
$psm1Path = "$($publishDir.FullName)\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psm1"
$utf8BomEncoding = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllText($psm1Path, $combinedContent, $utf8BomEncoding)
Write-Host "Wrote EasyPIM.Orchestrator.psm1 as UTF8 with BOM (enforced)" -ForegroundColor Yellow

# Note: Shared module removed - no manifest rewrite needed
# Write-Host "Manifest rewrite skipped: shared module removed" -ForegroundColor DarkCyan

# Test Module Import
Write-Host "Testing module import to catch any syntax errors..."
try {
    $raw = Get-Content "$($publishDir.FullName)\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psm1" -Raw -ErrorAction Stop
    $parseErrors = $null
    [System.Management.Automation.PSParser]::Tokenize($raw, [ref]$parseErrors) | Out-Null
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        Write-Host "STATIC PARSE ERRORS DETECTED:" -ForegroundColor Red
        $parseErrors | ForEach-Object { Write-Host ("Line {0}, Col {1}: {2}" -f $_.StartLine, $_.StartColumn, $_.Message) -ForegroundColor Red }
        throw "Static parse validation failed before Import-Module"
    } else {
        Write-Host "Static parse validation passed (no syntax errors)." -ForegroundColor Green
    }
    Import-Module -Name "$($publishDir.FullName)\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psd1" -Force -ErrorAction Stop
    Write-Host "Module imported successfully!" -ForegroundColor Green
    Remove-Module -Name EasyPIM.Orchestrator -ErrorAction SilentlyContinue
} catch {
    Write-Host "ERROR: Module failed to import or validate. Full details:" -ForegroundColor Red
    $_ | Format-List * -Force | Out-String | Write-Host -ForegroundColor Red
    throw "Module validation failed. See detailed error output above."
}

#region Updating the Module Version
if ($AutoVersion) {
    Write-Host  "Updating module version numbers."
    try { [version]$remoteVersion = (Find-Module 'EasyPIM.Orchestrator' -Repository $Repository -ErrorAction Stop).Version }
    catch { throw "Failed to access $($Repository) : $_" }
    if (-not $remoteVersion) { throw "Couldn't find EasyPIM.Orchestrator on repository $($Repository) : $_" }
    $newBuildNumber = $remoteVersion.Build + 1
    [version]$localVersion = (Import-PowerShellDataFile -Path "$($publishDir.FullName)\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psd1").ModuleVersion
    Update-ModuleManifest -Path "$($publishDir.FullName)\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psd1" -ModuleVersion "$($localVersion.Major).$($localVersion.Minor).$($newBuildNumber)"
}
#endregion

#region Publish
if ($SkipPublish) { return }
if ($LocalRepo) {
    Write-Host  "Creating Nuget Package for module: EasyPIM.Orchestrator"
    New-PSMDModuleNugetPackage -ModulePath "$($publishDir.FullName)\EasyPIM.Orchestrator" -PackagePath .
} else {
    Write-Host  "Publishing the EasyPIM.Orchestrator module to $($Repository)"
    Publish-Module -Path "$($publishDir.FullName)\EasyPIM.Orchestrator" -NuGetApiKey $ApiKey -Force -Repository $Repository
}
#endregion
