param (
    [string]
    $Repository = 'PSGallery'
)

$modules = @("Pester", "PSScriptAnalyzer")

# Automatically add missing dependencies
$data = Import-PowerShellDataFile -Path "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1"
foreach ($dependency in $data.RequiredModules) {
    if ($dependency -is [string]) {
        if ($modules -contains $dependency) { continue }
        $modules += $dependency
    }
    else {
        if ($modules -contains $dependency.ModuleName) { continue }
        $modules += $dependency.ModuleName
    }
}

foreach ($module in $modules) {
    Write-Host "Installing $module" -ForegroundColor Cyan
    
    # Special handling for Pester to ensure we get v5+ for parallel support
    if ($module -eq "Pester") {
        Write-Host "Installing latest Pester for parallel execution support..." -ForegroundColor Yellow
        Install-Module $module -Force -SkipPublisherCheck -Repository $Repository -AllowClobber -MinimumVersion "5.0.0"
        Import-Module $module -Force -PassThru
        $pesterVersion = (Get-Module $module).Version
        Write-Host "Pester version installed: $pesterVersion" -ForegroundColor Green
        if ($pesterVersion.Major -ge 5) {
            Write-Host "✅ Parallel execution support available" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Parallel execution not available (older version)" -ForegroundColor Yellow
        }
    } else {
        Install-Module $module -Force -SkipPublisherCheck -Repository $Repository -AllowClobber
        Import-Module $module -Force -PassThru
    }
}
