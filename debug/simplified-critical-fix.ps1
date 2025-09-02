# === SIMPLIFIED CRITICAL FIX FOR GITHUB ACTIONS OIDC ===
# Add this RIGHT AFTER: Import-Module EasyPIM.Orchestrator -Force

Write-Host "🚨 CRITICAL: Applying ARM authentication fix at module level..." -ForegroundColor Red

# Get working ARM token from Azure CLI
$armToken = az account get-access-token --resource https://management.azure.com/ --query accessToken --output tsv
if (-not $armToken) {
    Write-Error "❌ Failed to get ARM token from Azure CLI"
    exit 1
}

# Store token for module access
$env:AZURE_ACCESS_TOKEN = $armToken

Write-Host "✅ ARM token acquired and stored in environment" -ForegroundColor Green

# CRITICAL: Replace the Invoke-ARM function in the global scope
# This ensures all module calls use our fixed version
$Global:InvokeArmFixed = @'
function Global:Invoke-ARM {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $restURI,
        [Parameter(Position = 1)]
        [System.String]
        $method = "GET",
        [Parameter(Position = 2)]
        [System.String]
        $body = "",
        [Parameter(Position = 3)]
        [System.String]
        $SubscriptionId
    )

    try {
        $token = $env:AZURE_ACCESS_TOKEN
        if (-not $token) {
            throw "No ARM token in environment"
        }

        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type' = 'application/json'
        }

        $params = @{
            Uri = $restURI
            Method = $method
            Headers = $headers
            ErrorAction = 'Stop'
        }

        if ($method -in @("POST", "PUT", "PATCH") -and $body) {
            $params.Body = $body
        }

        return Invoke-RestMethod @params

    } catch {
        throw "ARM API call failed: $($_.Exception.Message)"
    }
}
'@

# Execute the function replacement
Invoke-Expression $Global:InvokeArmFixed

# Also try to replace it in the EasyPIM module's function table
try {
    $easyPimModule = Get-Module -Name EasyPIM
    if ($easyPimModule) {
        # Force the module to use our global function
        $easyPimModule.ExportedFunctions['Invoke-ARM'] = (Get-Command -Name Invoke-ARM)
        Write-Host "✅ Replaced Invoke-ARM in module function table" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  Could not replace module function table entry" -ForegroundColor Yellow
}

Write-Host "🎯 CRITICAL FIX APPLIED: All Invoke-ARM calls should now use working token" -ForegroundColor Green
# === END CRITICAL FIX ===
