param (
    $TestGeneral = $true,  # Add comma here

    $TestFunctions = $false,  # Add comma here

    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [Alias('Show')]
    $Output = "None",  # Add comma here

    $Include = "*",  # Add comma here

    $Exclude = ""  # No comma on last parameter
)

<#
POWERSHELL CROSS-VERSION COMPATIBILITY NOTES:
==============================================
This test suite is designed to work with both PowerShell 5.1 and 7.x environments.

PowerShell 5.1 (Pester v3/v4):
- Core module functionality tests: ✅ Fully supported
- Help documentation tests: ⚠️  Skipped (requires Pester v5+ syntax)
- PSScriptAnalyzer tests: ⚠️  Conditional (skipped if module not available)

PowerShell 7.x (Pester v5+):
- All tests: ✅ Fully supported

The EasyPIM module itself works identically in both PowerShell versions.
Test skipping ensures compatibility without breaking functionality validation.
#>

Write-Host "Starting Tests"
Write-Host "Importing Module"

$global:testroot = $PSScriptRoot
$global:__pester_data = @{ }

Remove-Module EasyPIM -ErrorAction Ignore
Import-Module "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1"
Import-Module "$PSScriptRoot\..\EasyPIM\EasyPIM.psm1" -Force

# Check Pester version and adjust accordingly
$pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
$pesterVersion = $pesterModule.Version

Write-Host "Detected Pester version: $pesterVersion"

# Compatibility notification
if ($pesterVersion.Major -lt 5) {
    Write-Host "Using Pester v3/v4 execution mode" -ForegroundColor Yellow
    Write-Host "NOTE: Some advanced tests (Help documentation) will be skipped for compatibility" -ForegroundColor Yellow
    Write-Host "Core module functionality testing is fully supported" -ForegroundColor Green
} else {
    Write-Host "Using Pester v5+ execution mode" -ForegroundColor Green
    Write-Host "All tests supported" -ForegroundColor Green
}

# Create test results directory
Write-Host "Creating test result folder"
$null = New-Item -Path "$PSScriptRoot\.." -Name TestResults -ItemType Directory -Force

$totalFailed = 0
$totalRun = 0
$testresults = @()

# Version-specific Pester handling
if ($pesterVersion.Major -ge 5) {
    # Pester v5 approach
    Write-Host "Using Pester v5 execution mode"
    Import-Module Pester -MinimumVersion 5.0.0
    $config = [PesterConfiguration]::Default
    $config.TestResult.Enabled = $true
    $config.Output.Verbosity = $Output

    #region Run General Tests
    if ($TestGeneral) {
        Write-Host "Modules imported, proceeding with general tests"
        foreach ($file in (Get-ChildItem "$PSScriptRoot\general" | Where-Object Name -like "*.Tests.ps1")) {
            if ($file.Name -notlike $Include) { continue }
            if ($file.Name -like $Exclude) { continue }

            Write-Host "  Executing $($file.Name)"
            $config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\TestResults" "TEST-$($file.BaseName).xml"
            $config.Run.Path = $file.FullName
            $config.Run.PassThru = $true
            $results = Invoke-Pester -Configuration $config

            # Process results
            foreach ($result in $results) {
                $totalRun += $result.TotalCount
                $totalFailed += $result.FailedCount
                $result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
                    $testresults += [pscustomobject]@{
                        Block   = $_.Block
                        Name    = "It $($_.Name)"
                        Result  = $_.Result
                        Message = $_.ErrorRecord.DisplayErrorMessage
                    }
                }
            }
        }
    }
} else {
    # Pester v3/v4 approach
    Write-Host "Using Pester v3/v4 execution mode"

    #region Run General Tests
    if ($TestGeneral) {
        Write-Host "Modules imported, proceeding with general tests"
        foreach ($file in (Get-ChildItem "$PSScriptRoot\general" | Where-Object Name -like "*.Tests.ps1")) {
            if ($file.Name -notlike $Include) { continue }
            if ($file.Name -like $Exclude) { continue }

            Write-Host "  Executing $($file.Name)"
            $testResultPath = Join-Path "$PSScriptRoot\..\TestResults" "TEST-$($file.BaseName).xml"

            # Use appropriate parameters for v3/v4
            if ($PesterVersion -ge [version]'5.0') {
                # Pester v5+ syntax
                $config = New-PesterConfiguration
                $config.Run.Path = $file.FullName
                $config.TestResult.Enabled = $true
                $config.TestResult.OutputPath = $testResultPath
                $config.TestResult.OutputFormat = 'NUnitXml'
                $results = Invoke-Pester -Configuration $config
            } else {
                # Pester v3/v4 syntax
                $results = Invoke-Pester -Script $file.FullName -OutputFile $testResultPath -OutputFormat 'NUnitXml' -PassThru
            }

            # Process results
            $totalRun += $results.TotalCount
            $totalFailed += $results.FailedCount
            $results.TestResult | Where-Object Result -ne 'Passed' | ForEach-Object {
                $testresults += [pscustomobject]@{
                    Name    = "It $($_.Name)"
                    Result  = $_.Result
                    Message = $_.FailureMessage
                }
            }
        }
    }
}

#region Test Commands
if ($TestFunctions) {
    Write-Host "Proceeding with individual tests"
    foreach ($file in (Get-ChildItem "$PSScriptRoot\functions" -Recurse -File | Where-Object Name -like "*Tests.ps1")) {
        if ($file.Name -notlike $Include) { continue }
        if ($file.Name -like $Exclude) { continue }

        Write-Host "  Executing $($file.Name)"
        $testResultPath = Join-Path "$PSScriptRoot\..\TestResults" "TEST-$($file.BaseName).xml"
        
        if ($PesterVersion -ge [version]'5.0') {
            # Pester v5+ syntax
            $config.TestResult.OutputPath = $testResultPath
            $config.Run.Path = $file.FullName
            $config.Run.PassThru = $true
            $results = Invoke-Pester -Configuration $config
            foreach ($result in $results) {
                $totalRun += $result.TotalCount
                $totalFailed += $result.FailedCount
                $result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
                    $testresults += [pscustomobject]@{
                        Block    = $_.Block
                        Name     = "It $($_.Name)"
                        Result   = $_.Result
                        Message  = $_.ErrorRecord.DisplayErrorMessage
                    }
                }
            }
        } else {
            # Pester v3/v4 syntax
            $results = Invoke-Pester -Script $file.FullName -OutputFile $testResultPath -OutputFormat 'NUnitXml' -PassThru
            $totalRun += $results.TotalCount
            $totalFailed += $results.FailedCount
            $results.TestResult | Where-Object Result -ne 'Passed' | ForEach-Object {
                $testresults += [pscustomobject]@{
                    Name    = "It $($_.Name)"
                    Result  = $_.Result
                    Message = $_.FailureMessage
                }
            }
        }
    }
}
#endregion Test Commands

# Display results
$testresults | Sort-Object Describe, Context, Name, Result, Message | Format-List

if ($totalFailed -eq 0) { Write-Host "All $totalRun tests executed without a single failure!" }
else { Write-Host "$totalFailed tests out of $totalRun tests failed!" }

if ($totalFailed -gt 0) {
    throw "$totalFailed / $totalRun tests failed!"
}
