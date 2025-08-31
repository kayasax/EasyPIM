# Optimized Pester test runner with parallel execution
Write-Host "=== EasyPIM Build Validation (Optimized) ===" -ForegroundColor Cyan

# Check Pester version and parallel capability  
Import-Module Pester -Force
$pesterVersion = (Get-Module Pester).Version
$processorCount = [Environment]::ProcessorCount

Write-Host "Build Environment:" -ForegroundColor Yellow
Write-Host "- Pester version: $pesterVersion"
Write-Host "- Processor count: $processorCount"

if ($pesterVersion.Major -ge 5) {
    Write-Host "✅ Using Pester v5+ with parallel execution" -ForegroundColor Green
    Write-Host "🚀 Running with $processorCount workers + Fast mode" -ForegroundColor Green
    
    # Run with optimal parallel settings for build validation
    & "$PSScriptRoot\..\tests\pester.ps1" -TestGeneral $true -TestFunctions $false -Output "Normal" -Fast -Parallel -Workers $processorCount
} else {
    Write-Host "⚠️  Using Pester v4 sequential execution" -ForegroundColor Yellow
    
    # Fallback to sequential with fast mode
    & "$PSScriptRoot\..\tests\pester.ps1" -TestGeneral $true -TestFunctions $false -Output "Normal" -Fast
}
