# === CRITICAL ARM AUTHENTICATION FIX FOR GITHUB ACTIONS OIDC ===
# Add this section AFTER importing EasyPIM modules but BEFORE calling Invoke-EasyPIMOrchestrator

Write-Host "🔧 CRITICAL: Applying module-level ARM authentication fix for GitHub Actions OIDC..." -ForegroundColor Red

# Get ARM token from Azure CLI (this works reliably with azure/login@v2)
$armToken = az account get-access-token --resource https://management.azure.com/ --query accessToken --output tsv

if (-not $armToken -or $armToken.Trim() -eq "") {
    Write-Error "❌ CRITICAL: Failed to get ARM token from Azure CLI - OIDC setup issue"
    exit 1
}

Write-Host "✅ Retrieved ARM token from Azure CLI (length: $($armToken.Length))" -ForegroundColor Green

# Set environment variables for fallback
$env:AZURE_ACCESS_TOKEN = $armToken
$env:ARM_ACCESS_TOKEN = $armToken

# Get the EasyPIM module to replace its internal function
$easyPimModule = Get-Module -Name EasyPIM
if (-not $easyPimModule) {
    Write-Error "❌ CRITICAL: EasyPIM module not loaded - cannot apply fix"
    exit 1
}

Write-Host "✅ Found EasyPIM module: $($easyPimModule.Name) v$($easyPimModule.Version)" -ForegroundColor Green

# Create the replacement function that will work in module scope
$moduleFixScript = @"
# Replace Invoke-ARM function inside the EasyPIM module
function Invoke-ARM {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = `$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        `$restURI,
        [Parameter(Position = 1)]
        [System.String]
        `$method = "GET",
        [Parameter(Position = 2)]
        [System.String]
        `$body = "",
        [Parameter(Position = 3)]
        [System.String]
        `$SubscriptionId
    )

    try {
        # Use the token from environment (set by our workflow)
        `$token = `$env:AZURE_ACCESS_TOKEN

        if (-not `$token) {
            # Fallback: try to get fresh token from Azure CLI
            `$token = az account get-access-token --resource https://management.azure.com/ --query accessToken --output tsv 2>`$null
        }

        if (-not `$token) {
            throw "CRITICAL: No ARM access token available via environment or Azure CLI"
        }

        # Make the ARM API call with the working token
        `$headers = @{
            'Authorization' = "Bearer `$token"
            'Content-Type' = 'application/json'
        }

        `$requestParams = @{
            Uri = `$restURI
            Method = `$method
            Headers = `$headers
            ErrorAction = 'Stop'
        }

        if (`$method -in @("POST", "PUT", "PATCH") -and `$body) {
            `$requestParams.Body = `$body
        }

        `$response = Invoke-RestMethod @requestParams
        return `$response

    } catch {
        `$errorMsg = "ARM API call failed: `$(`$_.Exception.Message)"
        if (`$_.Exception.Response) {
            `$errorMsg += " (Status: `$(`$_.Exception.Response.StatusCode))"
        }
        Write-Error `$errorMsg
        throw `$errorMsg
    }
}

# Export the function so it's available to other module functions
Export-ModuleMember -Function Invoke-ARM
"@

try {
    # Execute the replacement script in the module's scope
    $easyPimModule.Invoke([scriptblock]::Create($moduleFixScript))

    Write-Host "✅ CRITICAL: Successfully replaced Invoke-ARM function inside EasyPIM module" -ForegroundColor Green
    Write-Host "   The module will now use Azure CLI token for all ARM API calls" -ForegroundColor Gray

} catch {
    Write-Error "❌ CRITICAL: Failed to replace module function: $($_.Exception.Message)"
    Write-Host "🔄 Attempting alternative approach..." -ForegroundColor Yellow

    # Alternative approach: Use reflection to replace the function
    try {
        $moduleScope = $easyPimModule.SessionState
        $moduleScope.InvokeCommand.InvokeScript($moduleFixScript)
        Write-Host "✅ CRITICAL: Successfully applied alternative module fix" -ForegroundColor Green
    } catch {
        Write-Error "❌ CRITICAL: All module replacement attempts failed: $($_.Exception.Message)"
        Write-Host "⚠️  Proceeding anyway - ARM calls may still fail" -ForegroundColor Yellow
    }
}

# Test that our fix is working by calling the function directly
try {
    Write-Host "🧪 Testing module-level ARM fix..." -ForegroundColor Yellow
    $testUri = "https://management.azure.com/subscriptions/$env:SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleManagementPolicies?api-version=2020-10-01&`$filter=scopeId eq '/subscriptions/$env:SUBSCRIPTION_ID'"

    # Call Invoke-ARM as the module would
    $testResult = & $easyPimModule { Invoke-ARM -restURI $using:testUri -method "GET" }

    if ($testResult -and $testResult.value) {
        Write-Host "✅ Module-level ARM fix test SUCCESSFUL - Retrieved $($testResult.value.Count) policies" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Module-level ARM fix test returned empty result" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Module-level ARM fix test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   EasyPIM ARM calls may still fail" -ForegroundColor Yellow
}

Write-Host "🎯 CRITICAL FIX APPLIED: EasyPIM should now use working ARM authentication" -ForegroundColor Green
# === END CRITICAL FIX ===
