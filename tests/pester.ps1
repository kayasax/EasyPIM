param (
    $TestGeneral = $true,
    
    $TestFunctions = $false,
    
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [Alias('Show')]
    $Output = "None",
    
    $Include = "*",
    
    $Exclude = ""
)

Write-Host "Starting Tests"

Write-Host "Importing Module"

$global:testroot = $PSScriptRoot
$global:__pester_data = @{ }

Remove-Module EasyPIM -ErrorAction Ignore
Import-Module "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1"
Import-Module "$PSScriptRoot\..\EasyPIM\EasyPIM.psm1" -Force

# Import Pester
Import-Module Pester

# Check Pester version to handle backward compatibility
$isPester5 = (Get-Module Pester).Version.Major -ge 5

Write-Host "Creating test result folder"
$null = New-Item -Path "$PSScriptRoot\.." -Name TestResults -ItemType Directory -Force

$totalFailed = 0
$totalRun = 0

$testresults = @()

# Use appropriate configuration based on Pester version
if ($isPester5) {
    $config = [PesterConfiguration]::Default
    $config.TestResult.Enabled = $true
} else {
    # For Pester v3/v4, we'll use parameters directly
    Write-Host "Using Pester version 3/4 compatibility mode"
}

#region Run General Tests
if ($TestGeneral)
{
    Write-Host "Modules imported, proceeding with general tests"
    foreach ($file in (Get-ChildItem "$PSScriptRoot\general" | Where-Object Name -like "*.Tests.ps1"))
    {
        if ($file.Name -notlike $Include) { continue }
        if ($file.Name -like $Exclude) { continue }

        Write-Host "Executing $($file.Name)"
        $outputFile = Join-Path "$PSScriptRoot\..\TestResults" "TEST-$($file.BaseName).xml"
        
        if ($isPester5) {
            $config.TestResult.OutputPath = $outputFile
            $config.Run.Path = $file.FullName
            $config.Run.PassThru = $true
            $config.Output.Verbosity = $Output
            $results = Invoke-Pester -Configuration $config
        } else {
            # Pester v3/v4 style
            $results = Invoke-Pester -Script $file.FullName -OutputFile $outputFile -OutputFormat NUnitXml -PassThru `
                -Show $Output
        }
        
        foreach ($result in $results)
        {
            $totalRun += $result.TotalCount
            $totalFailed += $result.FailedCount
            
            if ($isPester5) {
                $result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
                    $testresults += [pscustomobject]@{
                        Block    = $_.Block
                        Name	 = "It $($_.Name)"
                        Result   = $_.Result
                        Message  = $_.ErrorRecord.DisplayErrorMessage
                    }
                }
            } else {
                # Pester v3/v4 stores results differently
                $result.TestResult | Where-Object Result -ne 'Passed' | ForEach-Object {
                    $testresults += [pscustomobject]@{
                        Block    = $_.Describe
                        Name	 = "It $($_.Name)"
                        Result   = $_.Result
                        Message  = $_.FailureMessage
                    }
                }
            }
        }
    }
}
#endregion Run General Tests

$global:__pester_data.ScriptAnalyzer | Out-Host

#region Test Commands
if ($TestFunctions)
{
    Write-Host "Proceeding with individual tests"
    foreach ($file in (Get-ChildItem "$PSScriptRoot\functions" -Recurse -File | Where-Object Name -like "*Tests.ps1"))
    {
        if ($file.Name -notlike $Include) { continue }
        if ($file.Name -like $Exclude) { continue }
        
        Write-Host "Executing $($file.Name)"
        $outputFile = Join-Path "$PSScriptRoot\..\TestResults" "TEST-$($file.BaseName).xml"
        
        if ($isPester5) {
            $config.TestResult.OutputPath = $outputFile
            $config.Run.Path = $file.FullName
            $config.Run.PassThru = $true
            $config.Output.Verbosity = $Output
            $results = Invoke-Pester -Configuration $config
        } else {
            # Pester v3/v4 style
            $results = Invoke-Pester -Script $file.FullName -OutputFile $outputFile -OutputFormat NUnitXml -PassThru `
                -Show $Output
        }
        
        foreach ($result in $results)
        {
            $totalRun += $result.TotalCount
            $totalFailed += $result.FailedCount
            
            if ($isPester5) {
                $result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
                    $testresults += [pscustomobject]@{
                        Block    = $_.Block
                        Name	 = "It $($_.Name)"
                        Result   = $_.Result
                        Message  = $_.ErrorRecord.DisplayErrorMessage
                    }
                }
            } else {
                # Pester v3/v4 stores results differently
                $result.TestResult | Where-Object Result -ne 'Passed' | ForEach-Object {
                    $testresults += [pscustomobject]@{
                        Block    = $_.Describe
                        Name	 = "It $($_.Name)"
                        Result   = $_.Result
                        Message  = $_.FailureMessage
                    }
                }
            }
        }
    }
}
#endregion Test Commands

$testresults | Sort-Object Describe, Context, Name, Result, Message | Format-List

if ($totalFailed -eq 0) { Write-Host "All $totalRun tests executed without a single failure!" }
else { Write-Host "$totalFailed tests out of $totalRun tests failed!" }

if ($totalFailed -gt 0)
{
    throw "$totalFailed / $totalRun tests failed!"
}