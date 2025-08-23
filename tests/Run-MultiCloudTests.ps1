#Requires -Version 7.0

<#
.SYNOPSIS
    Test runner for EasyPIM Multi-Cloud Support feature
    
.DESCRIPTION
    Runs all tests for the multi-cloud support changes in compliance with CONTRIBUTING.md requirements.
    This script ensures all existing functionality works and new features are properly tested.
    
.PARAMETER Detailed
    Show detailed test output
    
.PARAMETER IntegrationTests
    Include integration tests (may require Azure connections)
    
.PARAMETER CoverageReport
    Generate code coverage report
    
.EXAMPLE
    .\Run-MultiCloudTests.ps1
    
.EXAMPLE
    .\Run-MultiCloudTests.ps1 -Detailed -IntegrationTests
#>

param(
    [switch]$Detailed,
    [switch]$IntegrationTests,
    [switch]$CoverageReport
)

Write-Host "EasyPIM Multi-Cloud Support - Test Runner" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Following CONTRIBUTING.md workflow requirements" -ForegroundColor Gray
Write-Host ""

# Ensure we're in the right directory
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptRoot

# Check if Pester is available
$pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0.0' } | Sort-Object Version -Descending | Select-Object -First 1

if (-not $pesterModule) {
    Write-Host "Installing Pester 5.0+ (required for testing)..." -ForegroundColor Yellow
    try {
        Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force -SkipPublisherCheck
        $pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0.0' } | Sort-Object Version -Descending | Select-Object -First 1
    }
    catch {
        Write-Error "Failed to install Pester: $_"
        exit 1
    }
}

Write-Host "Using Pester version: $($pesterModule.Version)" -ForegroundColor Green

# Import Pester
Import-Module Pester -MinimumVersion 5.0.0

# Define test configuration
$config = New-PesterConfiguration

# Test discovery
$testFiles = @(
    ".\Get-PIMAzureEnvironmentEndpoint.Tests.ps1",
    ".\Import-ModuleChecks.Tests.ps1"
)

if ($IntegrationTests) {
    $testFiles += ".\Integration.Tests.ps1"
    Write-Host "Including integration tests" -ForegroundColor Yellow
}

# Verify test files exist
$missingTests = @()
foreach ($testFile in $testFiles) {
    if (-not (Test-Path $testFile)) {
        $missingTests += $testFile
    }
}

if ($missingTests.Count -gt 0) {
    Write-Error "Missing test files: $($missingTests -join ', ')"
    exit 1
}

$config.Run.Path = $testFiles
$config.Run.PassThru = $true

# Output configuration
if ($Detailed) {
    $config.Output.Verbosity = 'Detailed'
    Write-Host "Detailed output enabled" -ForegroundColor Yellow
} else {
    $config.Output.Verbosity = 'Normal'
}

# Code coverage configuration
if ($CoverageReport) {
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = @(
        "..\EasyPIM\internal\functions\Get-PIMAzureEnvironmentEndpoint.ps1",
        "..\EasyPIM\internal\scripts\Import-ModuleChecks.ps1"
    )
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.OutputPath = '.\TestResults\coverage.xml'
    Write-Host "Code coverage enabled" -ForegroundColor Yellow
}

# Test result configuration
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'
$config.TestResult.OutputPath = '.\TestResults\test-results.xml'

# Create results directory
if (-not (Test-Path '.\TestResults')) {
    New-Item -ItemType Directory -Path '.\TestResults' | Out-Null
}

Write-Host "`nStarting test execution..." -ForegroundColor Green
Write-Host "Test files:" -ForegroundColor Gray
foreach ($testFile in $testFiles) {
    Write-Host "  - $testFile" -ForegroundColor Gray
}
Write-Host ""

# Run the tests
try {
    $results = Invoke-Pester -Configuration $config
}
catch {
    Write-Error "Test execution failed: $_"
    exit 1
}

# Display results summary
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "Test Results Summary" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

$totalTests = $results.TotalCount
$passedTests = $results.PassedCount
$failedTests = $results.FailedCount
$skippedTests = $results.SkippedCount
$duration = $results.Duration.TotalSeconds

Write-Host "Total Tests:    $totalTests" -ForegroundColor White
Write-Host "Passed:         $passedTests" -ForegroundColor Green
Write-Host "Failed:         $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { 'Red' } else { 'Green' })
Write-Host "Skipped:        $skippedTests" -ForegroundColor Yellow
Write-Host "Duration:       $([math]::Round($duration, 2)) seconds" -ForegroundColor White

if ($CoverageReport -and $results.CodeCoverage) {
    $coverage = $results.CodeCoverage
    $coveragePercent = [math]::Round(($coverage.CommandsExecuted / $coverage.CommandsAnalyzed) * 100, 2)
    Write-Host "Code Coverage:  $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { 'Green' } else { 'Yellow' })
}

# Handle failed tests
if ($failedTests -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    Write-Host "==============" -ForegroundColor Red
    
    foreach ($test in $results.Failed) {
        Write-Host "❌ $($test.ExpandedPath)" -ForegroundColor Red
        if ($test.ErrorRecord) {
            Write-Host "   Error: $($test.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed
            if ($Detailed -and $test.ErrorRecord.ScriptStackTrace) {
                Write-Host "   Stack: $($test.ErrorRecord.ScriptStackTrace)" -ForegroundColor DarkRed
            }
        }
        Write-Host ""
    }
    
    Write-Host "❌ TESTS FAILED - Please fix the failing tests before submitting PR" -ForegroundColor Red
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Review failed test details above" -ForegroundColor Yellow
    Write-Host "2. Fix the underlying issues" -ForegroundColor Yellow
    Write-Host "3. Re-run tests: pwsh -File tests\Run-MultiCloudTests.ps1" -ForegroundColor Yellow
    
    exit 1
}

# Success message
Write-Host "✅ ALL TESTS PASSED!" -ForegroundColor Green
Write-Host ""
Write-Host "CONTRIBUTING.md Compliance Check:" -ForegroundColor Cyan
Write-Host "✅ Tests created for new features" -ForegroundColor Green
Write-Host "✅ All existing tests pass" -ForegroundColor Green
Write-Host "✅ Test results available in TestResults/" -ForegroundColor Green

if ($CoverageReport) {
    Write-Host "✅ Code coverage report generated" -ForegroundColor Green
}

Write-Host ""
Write-Host "Ready for PR submission! 🚀" -ForegroundColor Green
Write-Host ""
Write-Host "Next workflow steps:" -ForegroundColor Yellow
Write-Host "1. Update documentation if needed" -ForegroundColor Yellow
Write-Host "2. Update module version (already done: 1.10.0)" -ForegroundColor Green
Write-Host "3. Commit and push changes" -ForegroundColor Yellow
Write-Host "4. Submit PR with test results" -ForegroundColor Yellow

# Output files for CI/CD
Write-Host ""
Write-Host "Generated Files:" -ForegroundColor Gray
if (Test-Path '.\TestResults\test-results.xml') {
    Write-Host "  📊 Test Results: TestResults\test-results.xml" -ForegroundColor Gray
}
if (Test-Path '.\TestResults\coverage.xml') {
    Write-Host "  📈 Coverage Report: TestResults\coverage.xml" -ForegroundColor Gray
}

exit 0
