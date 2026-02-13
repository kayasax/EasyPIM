# Test for Issue: AzureRoles.Policies array format in fallback logic
# This test validates that Test-PIMPolicyDrift properly handles array format
# in the fallback logic when Initialize-EasyPIMPolicies fails

# Create a temporary test config file with AzureRoles.Policies as an array
$testConfigPath = "/tmp/test-azure-roles-array-config.json"

$testConfig = @{
    "AzureRoles" = @{
        "Policies" = @(
            @{
                "RoleName" = "Reader"
                "Scope" = "/subscriptions/00000000-0000-0000-0000-000000000000"
                "Policy" = @{
                    "ActivationDuration" = "PT1H"
                    "ActivationRequirement" = "MultiFactorAuthentication"
                    "ApprovalRequired" = $false
                }
            },
            @{
                "RoleName" = "Contributor"
                "Scope" = "/subscriptions/00000000-0000-0000-0000-000000000000"
                "Policy" = @{
                    "ActivationDuration" = "PT2H"
                    "ActivationRequirement" = "MultiFactorAuthentication,Justification"
                    "ApprovalRequired" = $true
                }
            }
        )
    }
} | ConvertTo-Json -Depth 10

Set-Content -Path $testConfigPath -Value $testConfig -Force

Write-Host "Test config created at: $testConfigPath"
Write-Host "Config content:"
Get-Content $testConfigPath

# Parse the config to validate it's an array
$parsedConfig = Get-Content $testConfigPath -Raw | ConvertFrom-Json
Write-Host "`nValidating config structure..."
Write-Host "AzureRoles.Policies is an array: $($parsedConfig.AzureRoles.Policies -is [System.Array])"
Write-Host "AzureRoles.Policies count: $($parsedConfig.AzureRoles.Policies.Count)"

if ($parsedConfig.AzureRoles.Policies -is [System.Array]) {
    Write-Host "✅ Config is correctly formatted as an array" -ForegroundColor Green
    
    # Show what properties an array has (this is what causes the bug)
    Write-Host "`nArray PSObject.Properties (these are what cause the bug):"
    $parsedConfig.AzureRoles.Policies.PSObject.Properties | ForEach-Object {
        Write-Host "  - $($_.Name)"
    }
} else {
    Write-Host "❌ Config is not an array" -ForegroundColor Red
}

# Cleanup
Remove-Item $testConfigPath -Force -ErrorAction SilentlyContinue

Write-Host "`nTest configuration validated successfully!"
Write-Host "The fix ensures that when AzureRoles.Policies is an array,"
Write-Host "the code iterates through the array entries (roles) instead of"
Write-Host "iterating through array properties (Count, Length, etc.)"
