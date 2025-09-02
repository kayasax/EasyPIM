# Enhanced Invoke-ARM for orchestrator use with full OIDC support
function Invoke-ARM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$restURI,
        [Parameter(Mandatory = $true)]
        [string]$method,
        [string]$body,
        [string]$subscriptionId
    )

    try {
        # Enhanced OIDC-compatible ARM token acquisition
        $token = $null
        $tokenAcquisitionErrors = @()
        $authMethod = "Unknown"
        
        # Method 1: Environment Variable (CI/CD Direct Token)
        if ($env:AZURE_ACCESS_TOKEN) {
            try {
                $token = $env:AZURE_ACCESS_TOKEN
                $authMethod = "Environment Variable (AZURE_ACCESS_TOKEN)"
                Write-Verbose "ARM token acquired from environment variable"
            } catch {
                $tokenAcquisitionErrors += "Environment variable: $($_.Exception.Message)"
            }
        }
        
        # Method 2: Azure PowerShell Context with Standard ARM Resource
        if (-not $token) {
            try {
                $azContext = Get-AzContext -ErrorAction Stop
                if ($azContext) {
                    $tokenObj = Get-AzAccessToken -ResourceUrl "https://management.azure.com/" -ErrorAction Stop
                    $token = if ($tokenObj.Token -is [System.Security.SecureString]) {
                        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenObj.Token))
                    } else {
                        $tokenObj.Token
                    }
                    $authMethod = "Azure PowerShell Context (ARM Resource)"
                    Write-Verbose "ARM token acquired via Azure PowerShell context with ARM resource"
                }
            } catch {
                $tokenAcquisitionErrors += "Azure PowerShell ARM resource: $($_.Exception.Message)"
            }
        }
        
        # Method 3: Azure PowerShell Context with Default Token (OIDC Compatible)
        if (-not $token) {
            try {
                $azContext = Get-AzContext -ErrorAction SilentlyContinue
                if ($azContext) {
                    $tokenObj = Get-AzAccessToken -ErrorAction Stop
                    $token = if ($tokenObj.Token -is [System.Security.SecureString]) {
                        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenObj.Token))
                    } else {
                        $tokenObj.Token
                    }
                    $authMethod = "Azure PowerShell Context (Default/OIDC)"
                    Write-Verbose "ARM token acquired via Azure PowerShell default method (OIDC compatible)"
                }
            } catch {
                $tokenAcquisitionErrors += "Azure PowerShell default: $($_.Exception.Message)"
            }
        }
        
        # Method 4: REST API Token Acquisition (OIDC Fallback)
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
                } elseif ($env:AZURE_CLIENT_ASSERTION) {
                    $body.client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
                    $body.client_assertion = $env:AZURE_CLIENT_ASSERTION
                }
                
                $response = Invoke-RestMethod -Uri $tokenEndpoint -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
                $token = $response.access_token
                $authMethod = "Direct OAuth2 (OIDC/Federated)"
                Write-Verbose "ARM token acquired via direct OAuth2 token endpoint"
            } catch {
                $tokenAcquisitionErrors += "Direct OAuth2: $($_.Exception.Message)"
            }
        }
        
        if (-not $token) {
            $errorMessage = @"
Failed to acquire ARM access token for Azure Resource Manager API calls.

Authentication Methods Attempted:
$($tokenAcquisitionErrors | ForEach-Object { "  - $_" } | Out-String)

Troubleshooting for OIDC/CI-CD environments:
1. Ensure AZURE_ACCESS_TOKEN environment variable is set with a valid ARM token
2. For federated credentials, ensure Connect-AzAccount was called with proper context
3. For service principals, ensure AZURE_CLIENT_ID and AZURE_TENANT_ID are set
4. Check that the token has the required ARM API permissions

Current Environment Variables:
  AZURE_CLIENT_ID: $($env:AZURE_CLIENT_ID -ne $null)
  AZURE_TENANT_ID: $($env:AZURE_TENANT_ID -ne $null)
  AZURE_ACCESS_TOKEN: $($env:AZURE_ACCESS_TOKEN -ne $null)
  AZURE_CLIENT_SECRET: $($env:AZURE_CLIENT_SECRET -ne $null)
  AZURE_CLIENT_ASSERTION: $($env:AZURE_CLIENT_ASSERTION -ne $null)
"@
            throw $errorMessage
        }
        
        Write-Verbose "ARM authentication successful using: $authMethod"

        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type' = 'application/json'
        }

        $params = @{
            Uri = $restURI
            Method = $method
            Headers = $headers
        }

        if ($body) {
            $params['Body'] = $body
        }

        Write-Verbose "Making ARM API call: $method $restURI"
        $response = Invoke-RestMethod @params
        return $response
    } catch {
        Write-Error "ARM API call failed: $($_.Exception.Message)"
        Write-Verbose "Failed URI: $restURI"
        Write-Verbose "Method: $method"
        Write-Verbose "Body: $body"
        throw
    }
}
