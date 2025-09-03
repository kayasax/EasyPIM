#Requires -Modules Az.Accounts

<#
.SYNOPSIS
Debug version of ARM authentication for GitHub Actions OIDC troubleshooting

.DESCRIPTION
This script tests all ARM authentication methods to identify what works in GitHub Actions with OIDC

.EXAMPLE
.\Test-ARMAuthentication-Debug.ps1 -SubscriptionId "your-sub-id" -Verbose
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$TestUri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Authorization/roleManagementPolicies?api-version=2020-10-01&`$filter=scopeId eq '/subscriptions/$SubscriptionId'"
)

Write-Host "🔍 EasyPIM ARM Authentication Debug Suite" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

$results = @{
    AzureContext = $false
    GetAzAccessToken = $false
    AzureCLI = $false
    EnvironmentVars = $false
    DirectARMCall = $false
    WorkingMethod = $null
    WorkingToken = $null
}

# Test 1: Azure PowerShell Context
Write-Host "`n🧪 Test 1: Azure PowerShell Context" -ForegroundColor Yellow
try {
    $azContext = Get-AzContext -ErrorAction Stop
    if ($azContext -and $azContext.Account) {
        Write-Host "✅ Azure PowerShell context found" -ForegroundColor Green
        Write-Host "   Account: $($azContext.Account.Id)" -ForegroundColor Gray
        Write-Host "   Tenant: $($azContext.Tenant.Id)" -ForegroundColor Gray
        Write-Host "   Subscription: $($azContext.Subscription.Name)" -ForegroundColor Gray
        $results.AzureContext = $true
    } else {
        Write-Host "❌ No Azure PowerShell context found" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Azure PowerShell context error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Get-AzAccessToken
Write-Host "`n🧪 Test 2: Get-AzAccessToken for ARM" -ForegroundColor Yellow
try {
    $tokenObj = Get-AzAccessToken -ResourceUrl "https://management.azure.com/" -ErrorAction Stop
    if ($tokenObj -and $tokenObj.Token) {
        $token = if ($tokenObj.Token -is [System.Security.SecureString]) {
            [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenObj.Token))
        } else {
            $tokenObj.Token
        }

        Write-Host "✅ Get-AzAccessToken succeeded" -ForegroundColor Green
        Write-Host "   Token type: $($tokenObj.Token.GetType().Name)" -ForegroundColor Gray
        Write-Host "   Token length: $($token.Length) characters" -ForegroundColor Gray
        Write-Host "   Expires: $($tokenObj.ExpiresOn)" -ForegroundColor Gray

        $results.GetAzAccessToken = $true
        $results.WorkingMethod = "Get-AzAccessToken"
        $results.WorkingToken = $token
    }
} catch {
    Write-Host "❌ Get-AzAccessToken failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Error type: $($_.Exception.GetType().Name)" -ForegroundColor Red
}

# Test 3: Azure CLI
Write-Host "`n🧪 Test 3: Azure CLI ARM Token" -ForegroundColor Yellow
try {
    $cliToken = az account get-access-token --resource https://management.azure.com/ --query accessToken --output tsv 2>$null
    if ($cliToken -and $cliToken.Trim() -ne "") {
        Write-Host "✅ Azure CLI ARM token acquired" -ForegroundColor Green
        Write-Host "   Token length: $($cliToken.Length) characters" -ForegroundColor Gray

        $results.AzureCLI = $true
        if (-not $results.WorkingToken) {
            $results.WorkingMethod = "Azure CLI"
            $results.WorkingToken = $cliToken
        }
    } else {
        Write-Host "❌ Azure CLI returned empty token" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Azure CLI failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Environment Variables
Write-Host "`n🧪 Test 4: Environment Variables" -ForegroundColor Yellow
$envVars = @('AZURE_ACCESS_TOKEN', 'ARM_ACCESS_TOKEN', 'AZURE_CLIENT_ID', 'AZURE_TENANT_ID', 'AZURE_CLIENT_SECRET', 'AZURE_CLIENT_ASSERTION')
foreach ($envVar in $envVars) {
    $value = [Environment]::GetEnvironmentVariable($envVar)
    if ($value) {
        Write-Host "✅ $envVar is set (length: $($value.Length))" -ForegroundColor Green
        if ($envVar -in @('AZURE_ACCESS_TOKEN', 'ARM_ACCESS_TOKEN')) {
            $results.EnvironmentVars = $true
            if (-not $results.WorkingToken) {
                $results.WorkingMethod = "Environment Variable: $envVar"
                $results.WorkingToken = $value
            }
        }
    } else {
        Write-Host "⚪ $envVar not set" -ForegroundColor Gray
    }
}

# Test 5: Direct ARM API Call
Write-Host "`n🧪 Test 5: Direct ARM API Call" -ForegroundColor Yellow
if ($results.WorkingToken) {
    try {
        $headers = @{
            'Authorization' = "Bearer $($results.WorkingToken)"
            'Content-Type' = 'application/json'
        }

        Write-Host "🌐 Testing ARM API call with $($results.WorkingMethod)..." -ForegroundColor Cyan
        Write-Host "   URI: $TestUri" -ForegroundColor Gray

        $response = Invoke-RestMethod -Uri $TestUri -Headers $headers -Method GET -ErrorAction Stop

        Write-Host "✅ ARM API call successful!" -ForegroundColor Green
        Write-Host "   Response type: $($response.GetType().Name)" -ForegroundColor Gray
        if ($response.value) {
            Write-Host "   Retrieved: $($response.value.Count) role management policies" -ForegroundColor Gray
        }

        $results.DirectARMCall = $true

    } catch {
        Write-Host "❌ ARM API call failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            Write-Host "   Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
            Write-Host "   Status Description: $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "⚠️  No working token found - skipping ARM API test" -ForegroundColor Yellow
}

# Summary
Write-Host "`n📊 SUMMARY RESULTS" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan
Write-Host "Azure Context Available:    $($results.AzureContext)" -ForegroundColor $(if($results.AzureContext) {'Green'} else {'Red'})
Write-Host "Get-AzAccessToken Works:    $($results.GetAzAccessToken)" -ForegroundColor $(if($results.GetAzAccessToken) {'Green'} else {'Red'})
Write-Host "Azure CLI Token Works:      $($results.AzureCLI)" -ForegroundColor $(if($results.AzureCLI) {'Green'} else {'Red'})
Write-Host "Environment Variables Set:  $($results.EnvironmentVars)" -ForegroundColor $(if($results.EnvironmentVars) {'Green'} else {'Red'})
Write-Host "Direct ARM Call Works:      $($results.DirectARMCall)" -ForegroundColor $(if($results.DirectARMCall) {'Green'} else {'Red'})

if ($results.WorkingMethod) {
    Write-Host "`n🎯 RECOMMENDED SOLUTION:" -ForegroundColor Green
    Write-Host "Working authentication method: $($results.WorkingMethod)" -ForegroundColor Green
    Write-Host "EasyPIM should use this method for ARM API calls" -ForegroundColor Green
} else {
    Write-Host "`n❌ NO WORKING AUTHENTICATION METHOD FOUND" -ForegroundColor Red
    Write-Host "This indicates a fundamental authentication issue" -ForegroundColor Red
}

return $results
