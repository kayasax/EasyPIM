<#
.SYNOPSIS
Enhanced Invoke-ARM with comprehensive debugging for GitHub Actions OIDC

.DESCRIPTION
Local development version of Invoke-ARM with detailed logging and multiple fallback methods
#>
function Invoke-ARM-Debug {
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

    Write-Host "🔍 [DEBUG] Starting ARM API call" -ForegroundColor Cyan
    Write-Host "   URI: $restURI" -ForegroundColor Gray
    Write-Host "   Method: $method" -ForegroundColor Gray

    try {
        $token = $null
        $tokenAcquisitionErrors = @()
        $authMethod = "Unknown"

        # Method 1: Azure PowerShell Context with detailed debugging
        Write-Host "🧪 [DEBUG] Attempting Method 1: Azure PowerShell Context" -ForegroundColor Yellow
        if (-not $token) {
            try {
                $azContext = Get-AzContext -ErrorAction Stop
                Write-Host "   Context found: $($azContext.Account.Id)" -ForegroundColor Gray
                
                if ($azContext -and $azContext.Account) {
                    Write-Host "   Requesting ARM token..." -ForegroundColor Gray
                    $tokenObj = Get-AzAccessToken -ResourceUrl "https://management.azure.com/" -ErrorAction Stop
                    
                    $token = if ($tokenObj.Token -is [System.Security.SecureString]) {
                        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenObj.Token))
                    } else {
                        $tokenObj.Token
                    }
                    
                    $authMethod = "Azure PowerShell Context (Official Pattern)"
                    Write-Host "✅ [DEBUG] Method 1 succeeded - Token length: $($token.Length)" -ForegroundColor Green
                }
            } catch {
                $errorMsg = $_.Exception.Message
                $tokenAcquisitionErrors += "Azure PowerShell Context: $errorMsg"
                Write-Host "❌ [DEBUG] Method 1 failed: $errorMsg" -ForegroundColor Red
            }
        }

        # Method 2: Environment Variables with debugging
        Write-Host "🧪 [DEBUG] Attempting Method 2: Environment Variables" -ForegroundColor Yellow
        if (-not $token) {
            $envToken = $env:AZURE_ACCESS_TOKEN -or $env:ARM_ACCESS_TOKEN
            if ($envToken) {
                try {
                    $token = $envToken
                    $authMethod = "Environment Variable"
                    Write-Host "✅ [DEBUG] Method 2 succeeded - Using env token" -ForegroundColor Green
                } catch {
                    $tokenAcquisitionErrors += "Environment variable: $($_.Exception.Message)"
                    Write-Host "❌ [DEBUG] Method 2 failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "⚪ [DEBUG] Method 2 skipped - No env tokens found" -ForegroundColor Gray
            }
        }

        # Method 3: Azure CLI with debugging
        Write-Host "🧪 [DEBUG] Attempting Method 3: Azure CLI" -ForegroundColor Yellow
        if (-not $token) {
            try {
                Write-Host "   Requesting CLI token..." -ForegroundColor Gray
                $cliToken = az account get-access-token --resource https://management.azure.com/ --query accessToken --output tsv 2>$null
                
                if ($cliToken -and $cliToken.Trim() -ne "") {
                    $token = $cliToken.Trim()
                    $authMethod = "Azure CLI"
                    Write-Host "✅ [DEBUG] Method 3 succeeded - Token length: $($token.Length)" -ForegroundColor Green
                } else {
                    throw "Azure CLI returned empty token"
                }
            } catch {
                $tokenAcquisitionErrors += "Azure CLI: $($_.Exception.Message)"
                Write-Host "❌ [DEBUG] Method 3 failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        # Method 4: Service Principal with debugging
        Write-Host "🧪 [DEBUG] Attempting Method 4: Service Principal" -ForegroundColor Yellow
        if (-not $token -and $env:AZURE_CLIENT_ID -and $env:AZURE_TENANT_ID) {
            try {
                $tokenEndpoint = "https://login.microsoftonline.com/$($env:AZURE_TENANT_ID)/oauth2/v2.0/token"
                
                $body = @{
                    client_id = $env:AZURE_CLIENT_ID
                    scope = "https://management.azure.com/.default"
                    grant_type = "client_credentials"
                }

                if ($env:AZURE_CLIENT_SECRET) {
                    $body.client_secret = $env:AZURE_CLIENT_SECRET
                    Write-Host "   Using client secret..." -ForegroundColor Gray
                } elseif ($env:AZURE_CLIENT_ASSERTION) {
                    $body.client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
                    $body.client_assertion = $env:AZURE_CLIENT_ASSERTION
                    Write-Host "   Using client assertion..." -ForegroundColor Gray
                } else {
                    throw "Service principal requires AZURE_CLIENT_SECRET or AZURE_CLIENT_ASSERTION"
                }

                $response = Invoke-RestMethod -Uri $tokenEndpoint -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
                $token = $response.access_token
                $authMethod = "Service Principal (Direct OAuth2)"
                Write-Host "✅ [DEBUG] Method 4 succeeded - Token acquired" -ForegroundColor Green
            } catch {
                $tokenAcquisitionErrors += "Service Principal: $($_.Exception.Message)"
                Write-Host "❌ [DEBUG] Method 4 failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "⚪ [DEBUG] Method 4 skipped - Missing service principal env vars" -ForegroundColor Gray
        }

        if (-not $token) {
            Write-Host "❌ [FATAL] All authentication methods failed!" -ForegroundColor Red
            foreach ($errorMsg in $tokenAcquisitionErrors) {
                Write-Host "   - $errorMsg" -ForegroundColor Red
            }
            throw "Failed to acquire ARM access token. Tried: $($tokenAcquisitionErrors.Count) methods"
        }

        Write-Host "🎯 [SUCCESS] Using authentication method: $authMethod" -ForegroundColor Green

        # Make the ARM API call with debugging
        Write-Host "🌐 [DEBUG] Making ARM API call..." -ForegroundColor Cyan
        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type' = 'application/json'
        }

        $requestParams = @{
            Uri = $restURI
            Method = $method
            Headers = $headers
        }

        if ($method -in @("POST", "PUT", "PATCH") -and $body) {
            $requestParams.Body = $body
            Write-Host "   Body length: $($body.Length) characters" -ForegroundColor Gray
        }

        $response = Invoke-RestMethod @requestParams -ErrorAction Stop
        Write-Host "✅ [SUCCESS] ARM API call completed successfully" -ForegroundColor Green

        return $response

    } catch {
        Write-Host "❌ [ERROR] ARM API call failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            Write-Host "   Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        }
        throw "ARM API call failed: $($_.Exception.Message)"
    }
}
