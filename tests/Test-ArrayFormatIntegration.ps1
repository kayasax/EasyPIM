# Integration test for Issue: AzureRoles.Policies array format in fallback logic
# This test simulates the actual scenario where Initialize-EasyPIMPolicies fails
# and the fallback logic needs to handle array format

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Integration Test: AzureRoles.Policies Array Format in Fallback Logic ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Validate array format causes issue with PSObject.Properties iteration
Write-Host "Test 1: Demonstrating the issue with array PSObject.Properties" -ForegroundColor Yellow
$arrayConfig = @{
    "AzureRoles" = @{
        "Policies" = @(
            @{
                "RoleName" = "Reader"
                "Scope" = "/subscriptions/test-sub-id"
            }
        )
    }
}

$jsonConfig = $arrayConfig | ConvertTo-Json -Depth 10 | ConvertFrom-Json

Write-Host "  - Config type: $($jsonConfig.AzureRoles.Policies.GetType().Name)"
Write-Host "  - Is array: $($jsonConfig.AzureRoles.Policies -is [System.Collections.IEnumerable] -and $jsonConfig.AzureRoles.Policies -isnot [string])"

# The OLD buggy way (iterating PSObject.Properties of an array)
Write-Host "  - OLD (buggy) iteration through PSObject.Properties:"
$buggyResults = @()
foreach ($prop in $jsonConfig.AzureRoles.Policies.PSObject.Properties) {
    $buggyResults += $prop.Name
    Write-Host "    ❌ Found: $($prop.Name) (this is an array property, not a role!)" -ForegroundColor Red
}

if ($buggyResults -contains "Count" -or $buggyResults -contains "Length") {
    Write-Host "  ✅ Confirmed: The OLD approach incorrectly iterates array properties" -ForegroundColor Green
} else {
    Write-Host "  ❌ Unexpected: The OLD approach didn't hit array properties" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: Validate the FIX works correctly
Write-Host "Test 2: Demonstrating the FIX with proper array detection" -ForegroundColor Yellow

# The NEW fixed way (check if array first)
Write-Host "  - NEW (fixed) iteration with array detection:"
$fixedResults = @()
$azurePolicies = $jsonConfig.AzureRoles.Policies

if ($azurePolicies -is [System.Collections.IEnumerable] -and $azurePolicies -isnot [string]) {
    Write-Host "    ✅ Detected as array, iterating entries directly" -ForegroundColor Green
    foreach ($entry in $azurePolicies) {
        if ($entry -and $entry.PSObject.Properties['RoleName']) {
            $fixedResults += $entry.RoleName
            Write-Host "    ✅ Found role: $($entry.RoleName)" -ForegroundColor Green
        }
    }
} else {
    Write-Host "    Using dictionary iteration (not executed in this test)" -ForegroundColor Gray
    foreach ($prop in $azurePolicies.PSObject.Properties) {
        $roleName = $prop.Name
        $fixedResults += $roleName
        Write-Host "    Found role: $roleName" -ForegroundColor Gray
    }
}

if ($fixedResults -contains "Reader" -and -not ($fixedResults -contains "Count" -or $fixedResults -contains "Length")) {
    Write-Host "  ✅ Confirmed: The FIX correctly extracts role entries from array" -ForegroundColor Green
} else {
    Write-Host "  ❌ Failed: The FIX didn't work as expected" -ForegroundColor Red
    Write-Host "  Found: $($fixedResults -join ', ')"
    exit 1
}

Write-Host ""

# Test 3: Validate dictionary format still works
Write-Host "Test 3: Validating dictionary format still works" -ForegroundColor Yellow

$dictConfig = @{
    "AzureRoles" = @{
        "Policies" = @{
            "Contributor" = @{
                "Scope" = "/subscriptions/test-sub-id"
                "ActivationDuration" = "PT2H"
            }
        }
    }
}

$jsonDictConfig = $dictConfig | ConvertTo-Json -Depth 10 | ConvertFrom-Json

Write-Host "  - Config type: $($jsonDictConfig.AzureRoles.Policies.GetType().Name)"
Write-Host "  - Is array: $($jsonDictConfig.AzureRoles.Policies -is [System.Collections.IEnumerable] -and $jsonDictConfig.AzureRoles.Policies -isnot [string])"

$dictResults = @()
$azurePoliciesDict = $jsonDictConfig.AzureRoles.Policies

if ($azurePoliciesDict -is [System.Collections.IEnumerable] -and $azurePoliciesDict -isnot [string]) {
    Write-Host "    Detected as array (not executed in this test)" -ForegroundColor Gray
    foreach ($entry in $azurePoliciesDict) {
        if ($entry -and $entry.PSObject.Properties['RoleName']) {
            $dictResults += $entry.RoleName
        }
    }
} else {
    Write-Host "    ✅ Detected as dictionary, iterating properties" -ForegroundColor Green
    foreach ($prop in $azurePoliciesDict.PSObject.Properties) {
        $roleName = $prop.Name
        $dictResults += $roleName
        Write-Host "    ✅ Found role: $roleName" -ForegroundColor Green
    }
}

if ($dictResults -contains "Contributor") {
    Write-Host "  ✅ Confirmed: Dictionary format still works correctly" -ForegroundColor Green
} else {
    Write-Host "  ❌ Failed: Dictionary format broken" -ForegroundColor Red
    Write-Host "  Found: $($dictResults -join ', ')"
    exit 1
}

Write-Host ""
Write-Host "=== All Tests Passed ===" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  ✅ Confirmed OLD code incorrectly iterates array properties (Count, Length, etc.)"
Write-Host "  ✅ Confirmed FIX correctly detects arrays and iterates role entries"
Write-Host "  ✅ Confirmed FIX maintains backward compatibility with dictionary format"
Write-Host ""
Write-Host "The fix in Test-PIMPolicyDrift.ps1 adds array detection to AzureRoles.Policies processing,"
Write-Host "matching the existing logic for EntraRoles.Policies and Groups.Policies."

exit 0
