# Inline ARM Authentication Hotfix for GitHub Actions OIDC
# Add this section to your workflow after installing EasyPIM modules but before calling Invoke-EasyPIMOrchestrator

Write-Host "🔧 Applying inline ARM authentication hotfix for GitHub Actions OIDC..." -ForegroundColor Cyan

# Get ARM token from Azure CLI (this works reliably with azure/login@v2)
$armToken = az account get-access-token --resource https://management.azure.com/ --query accessToken --output tsv

if (-not $armToken) {
    Write-Error "❌ Failed to get ARM token from Azure CLI"
    exit 1
}

Write-Host "✅ Retrieved ARM token from Azure CLI" -ForegroundColor Green

# Set environment variables that our hotfix will use
$env:AZURE_ACCESS_TOKEN = $armToken
$env:ARM_ACCESS_TOKEN = $armToken

Write-Host "✅ Set ARM token environment variables" -ForegroundColor Green

# Override the Invoke-ARM function with a GitHub Actions compatible version
$invokeArmOverride = @'
function Invoke-ARM {
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
        # Use environment variable token first (set by workflow)
        $token = $env:AZURE_ACCESS_TOKEN -or $env:ARM_ACCESS_TOKEN
        
        if (-not $token) {
            # Fallback to Azure CLI
            $token = az account get-access-token --resource https://management.azure.com/ --query accessToken --output tsv 2>$null
        }
        
        if (-not $token) {
            # Last resort: Azure PowerShell
            $azContext = Get-AzContext -ErrorAction SilentlyContinue
            if ($azContext) {
                $tokenObj = Get-AzAccessToken -ResourceUrl "https://management.azure.com/" -ErrorAction SilentlyContinue
                if ($tokenObj) {
                    $token = if ($tokenObj.Token -is [System.Security.SecureString]) {
                        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenObj.Token))
                    } else {
                        $tokenObj.Token
                    }
                }
            }
        }

        if (-not $token) {
            throw "Failed to acquire ARM access token via any method (env vars, Azure CLI, or Azure PowerShell)"
        }

        # Make the ARM API call
        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type' = 'application/json'
        }

        $requestParams = @{
            Uri = $restURI
            Method = $method
            Headers = $headers
            ErrorAction = 'Stop'
        }

        if ($method -in @("POST", "PUT", "PATCH") -and $body) {
            $requestParams.Body = $body
        }

        return Invoke-RestMethod @requestParams

    } catch {
        $errorMsg = "ARM API call failed: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $errorMsg += " (Status: $($_.Exception.Response.StatusCode))"
        }
        throw $errorMsg
    }
}
'@

# Execute the function override
Invoke-Expression $invokeArmOverride

Write-Host "✅ ARM authentication hotfix applied - Invoke-ARM function overridden" -ForegroundColor Green
Write-Host "   EasyPIM will now use environment variable token for ARM calls" -ForegroundColor Gray

# Test the override works
try {
    Write-Host "🧪 Testing ARM authentication override..." -ForegroundColor Yellow
    $testUri = "https://management.azure.com/subscriptions/$env:SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleManagementPolicies?api-version=2020-10-01&`$filter=scopeId eq '/subscriptions/$env:SUBSCRIPTION_ID'"
    $testResult = Invoke-ARM -restURI $testUri -method "GET"
    Write-Host "✅ ARM authentication test successful - Retrieved $($testResult.value.Count) policies" -ForegroundColor Green
} catch {
    Write-Warning "⚠️  ARM authentication test failed: $($_.Exception.Message)"
    Write-Host "   EasyPIM may still fail, but the hotfix has been applied" -ForegroundColor Gray
}
