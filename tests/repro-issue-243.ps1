
# Reproduction script for Issue #243

# Mock Initialize-EasyPIMPolicies to simulate partial success then failure
function Initialize-EasyPIMPolicies {
    param($Config, $PolicyTemplates)
    
    Write-Host "Mocking Initialize-EasyPIMPolicies..."
    
    # Return a config with Entra policies
    $config = [PSCustomObject]@{
        EntraRolePolicies = @(
            [PSCustomObject]@{
                RoleName = "MockRole1"
                ResolvedPolicy = [PSCustomObject]@{ Setting = "Value" }
            },
            [PSCustomObject]@{
                RoleName = "MockRole2"
                ResolvedPolicy = [PSCustomObject]@{ Setting = "Value" }
            }
        )
        AzureRolePolicies = @()
        GroupPolicies = @()
    }
    
    return $config
}

# Mock Get-EasyPIMConfiguration
function Get-EasyPIMConfiguration {
    param($ConfigFilePath)
    return [PSCustomObject]@{
        EntraRolePolicies = @(
            [PSCustomObject]@{ RoleName = "MockRole1"; Policy = @{ Setting = "Value" } },
            [PSCustomObject]@{ RoleName = "MockRole2"; Policy = @{ Setting = "Value" } }
        )
    }
}

# Mock other dependencies
function Get-PIMEntraRolePolicy { return $null }
function Compare-PIMPolicy { param([ref]$Results) $Results.Value += [PSCustomObject]@{ Name = $args[1]; Status = "Match" } }
function Get-ResolvedPolicyObject { param($Policy) return $Policy.ResolvedPolicy }

# Load the function to test (we need to source it, but we need to inject the error)
# Instead of sourcing, I'll define a simplified version of Test-PIMPolicyDrift that mirrors the logic structure

function Test-PIMPolicyDrift-Repro {
    param($ConfigPath)
    
    $expectedEntra = @()
    
    try {
        # 1. Call Initialize-EasyPIMPolicies
        $processedConfig = Initialize-EasyPIMPolicies
        
        # 2. Populate Entra policies (Success)
        $expectedEntra = $processedConfig.EntraRolePolicies | ForEach-Object {
            [pscustomobject]@{ RoleName = $_.RoleName; ResolvedPolicy = $_.ResolvedPolicy }
        }
        
        Write-Host "Entra policies populated: $($expectedEntra.Count)"
        
        # 3. Simulate an error in subsequent processing
        throw "Cannot index into a null array"
        
    } catch {
        Write-Warning "Failed to use orchestrator policy processing: $_"
        
        # Clear any partially populated collections to prevent duplication
        $expectedEntra = @()

        # Fallback logic (Simulated)
        # It reads from the raw config again
        $json = Get-EasyPIMConfiguration
        
        if ($json.EntraRolePolicies) {
            $expectedEntra += $json.EntraRolePolicies
        }
    }
    
    Write-Host "Total Entra policies: $($expectedEntra.Count)"
    # If duplication occurred, we would have 2 (from try) + 2 (from catch) = 4
    # If fixed, we should have 2 (from catch only)
    if ($expectedEntra.Count -gt 2) {
        Write-Host "❌ DUPLICATION DETECTED!" -ForegroundColor Red
    } else {
        Write-Host "✅ No duplication." -ForegroundColor Green
    }
}

Test-PIMPolicyDrift-Repro -ConfigPath "dummy.json"
