#Requires -Version 5.1

<#
.SYNOPSIS
EasyPIM ARM Authentication Hotfix for GitHub Actions OIDC

.DESCRIPTION
This script replaces the Invoke-ARM function in the already-loaded EasyPIM module
with a fixed version that works better with GitHub Actions OIDC authentication.

.EXAMPLE
# Add this to your GitHub Actions workflow AFTER installing EasyPIM:
. ./debug/EasyPIM-OIDC-Hotfix.ps1

.NOTES
This is a temporary workaround until the fix is published to PowerShell Gallery
#>

Write-Host "🔧 [HOTFIX] Applying EasyPIM ARM authentication fix for GitHub Actions OIDC..." -ForegroundColor Cyan

# Enhanced Invoke-ARM function that works better with GitHub Actions OIDC
$InvokeARMFunction = {
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
            $token = $null
            $tokenAcquisitionErrors = @()
            $authMethod = "Unknown"

            # Method 1: Environment Variables (Prioritized for GitHub Actions)
            # This works best when tokens are pre-set by workflow
            if (-not $token -and ($env:AZURE_ACCESS_TOKEN -or $env:ARM_ACCESS_TOKEN)) {
                try {
                    $token = $env:AZURE_ACCESS_TOKEN -or $env:ARM_ACCESS_TOKEN
                    $authMethod = "Environment Variable (AZURE_ACCESS_TOKEN)"
                    Write-Verbose "ARM token acquired from environment variable (GitHub Actions compatible)"
                } catch {
                    $tokenAcquisitionErrors += "Environment variable: $($_.Exception.Message)"
                }
            }

            # Method 2: Azure CLI (Works reliably with azure/login@v2)
            if (-not $token) {
                try {
                    $cliToken = az account get-access-token --resource https://management.azure.com/ --query accessToken --output tsv 2>$null
                    if ($cliToken -and $cliToken.Trim() -ne "") {
                        $token = $cliToken.Trim()
                        $authMethod = "Azure CLI (GitHub Actions OIDC)"
                        Write-Verbose "ARM token acquired from Azure CLI - compatible with azure/login@v2"
                    } else {
                        throw "Azure CLI returned empty token"
                    }
                } catch {
                    $tokenAcquisitionErrors += "Azure CLI: $($_.Exception.Message)"
                }
            }

            # Method 3: Azure PowerShell Context (May fail in GitHub Actions)
            if (-not $token) {
                try {
                    $azContext = Get-AzContext -ErrorAction Stop
                    if ($azContext -and $azContext.Account) {
                        $tokenObj = Get-AzAccessToken -ResourceUrl "https://management.azure.com/" -ErrorAction Stop
                        $token = if ($tokenObj.Token -is [System.Security.SecureString]) {
                            [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenObj.Token))
                        } else {
                            $tokenObj.Token
                        }
                        $authMethod = "Azure PowerShell Context"
                        Write-Verbose "ARM token acquired from Azure PowerShell context"
                    }
                } catch {
                    $tokenAcquisitionErrors += "Azure PowerShell Context: $($_.Exception.Message)"
                }
            }

            # Method 4: Service Principal (Last resort)
            if (-not $token -and $env:AZURE_CLIENT_ID -and $env:AZURE_TENANT_ID) {
                try {
                    $tokenEndpoint = "https://login.microsoftonline.com/$($env:AZURE_TENANT_ID)/oauth2/v2.0/token"
                    
                    $tokenBody = @{
                        client_id = $env:AZURE_CLIENT_ID
                        scope = "https://management.azure.com/.default"
                        grant_type = "client_credentials"
                    }

                    if ($env:AZURE_CLIENT_SECRET) {
                        $tokenBody.client_secret = $env:AZURE_CLIENT_SECRET
                    } elseif ($env:AZURE_CLIENT_ASSERTION) {
                        $tokenBody.client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
                        $tokenBody.client_assertion = $env:AZURE_CLIENT_ASSERTION
                    } else {
                        throw "Service principal requires AZURE_CLIENT_SECRET or AZURE_CLIENT_ASSERTION"
                    }

                    $response = Invoke-RestMethod -Uri $tokenEndpoint -Method POST -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
                    $token = $response.access_token
                    $authMethod = "Service Principal (Direct OAuth2)"
                    Write-Verbose "ARM token acquired via service principal authentication"
                } catch {
                    $tokenAcquisitionErrors += "Service Principal: $($_.Exception.Message)"
                }
            }

            if (-not $token) {
                $errorMessage = @"
HOTFIX: Failed to acquire ARM access token for Azure Resource Manager API calls.

Authentication Methods Attempted:
$($tokenAcquisitionErrors | ForEach-Object { "  - $_" } | Out-String)

GitHub Actions Troubleshooting:
1. Ensure azure/login@v2 action includes 'enable-AzPSSession: true'
2. Verify OIDC federated credentials are configured correctly
3. Check that the service principal has required ARM permissions

Current Environment Context:
  AZURE_CLIENT_ID: $($null -ne $env:AZURE_CLIENT_ID)
  AZURE_TENANT_ID: $($null -ne $env:AZURE_TENANT_ID)
  AZURE_ACCESS_TOKEN: $($null -ne $env:AZURE_ACCESS_TOKEN)
  ARM_ACCESS_TOKEN: $($null -ne $env:ARM_ACCESS_TOKEN)
"@
                throw $errorMessage
            }

            Write-Verbose "HOTFIX: Using authentication method: $authMethod"

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

            $response = Invoke-RestMethod @requestParams
            Write-Verbose "HOTFIX: ARM API call completed successfully using $authMethod"
            
            return $response

        } catch {
            $errorMsg = "ARM API call failed: $($_.Exception.Message)"
            if ($_.Exception.Response) {
                $errorMsg += " (Status: $($_.Exception.Response.StatusCode))"
            }
            Write-Error $errorMsg
            throw $errorMsg
        }
    }
}

# Replace the function in the current session
try {
    # Execute the function definition
    & $InvokeARMFunction
    
    # Verify the function was created
    if (Get-Command Invoke-ARM -ErrorAction SilentlyContinue) {
        Write-Host "✅ [HOTFIX] Invoke-ARM function successfully replaced with OIDC-compatible version" -ForegroundColor Green
        Write-Host "   This version prioritizes Azure CLI and environment variable authentication" -ForegroundColor Gray
        Write-Host "   which works better with GitHub Actions azure/login@v2 OIDC setup" -ForegroundColor Gray
    } else {
        Write-Warning "⚠️  [HOTFIX] Failed to verify Invoke-ARM function replacement"
    }
} catch {
    Write-Error "❌ [HOTFIX] Failed to apply ARM authentication fix: $($_.Exception.Message)"
    throw
}

Write-Host "🎯 [HOTFIX] ARM authentication fix applied. EasyPIM should now work with GitHub Actions OIDC." -ForegroundColor Green
