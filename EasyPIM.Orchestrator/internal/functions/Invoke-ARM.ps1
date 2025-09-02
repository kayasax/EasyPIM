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

        # Method 1: Azure PowerShell Context (PREFERRED - Official Microsoft Pattern)
        # Supports GitHub Actions with azure/login@v2 action using OIDC
        if (-not $token) {
            try {
                $azContext = Get-AzContext -ErrorAction Stop
                if ($azContext -and $azContext.Account) {
                    # Use Get-AzAccessToken for ARM resource (recommended approach)
                    $tokenObj = Get-AzAccessToken -ResourceUrl "https://management.azure.com/" -ErrorAction Stop
                    $token = if ($tokenObj.Token -is [System.Security.SecureString]) {
                        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenObj.Token))
                    } else {
                        $tokenObj.Token
                    }
                    $authMethod = "Azure PowerShell Context (Official Pattern)"
                    Write-Verbose "ARM token acquired from Azure PowerShell context - this works with azure/login@v2 OIDC in GitHub Actions"
                }
            } catch {
                $tokenAcquisitionErrors += "Azure PowerShell Context: $($_.Exception.Message)"
            }
        }

        # Method 2: Direct Environment Variable (CI/CD Fallback)
        if (-not $token -and $env:AZURE_ACCESS_TOKEN) {
            try {
                $token = $env:AZURE_ACCESS_TOKEN
                $authMethod = "Environment Variable (AZURE_ACCESS_TOKEN)"
                Write-Verbose "ARM token acquired from environment variable"
            } catch {
                $tokenAcquisitionErrors += "Environment variable: $($_.Exception.Message)"
            }
        }

        # Method 3: Service Principal Authentication (Fallback)
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
                    Write-Verbose "Using service principal with client secret for ARM token"
                } elseif ($env:AZURE_CLIENT_ASSERTION) {
                    $body.client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
                    $body.client_assertion = $env:AZURE_CLIENT_ASSERTION
                    Write-Verbose "Using service principal with client assertion for ARM token"
                } else {
                    throw "Service principal requires AZURE_CLIENT_SECRET or AZURE_CLIENT_ASSERTION"
                }

                $response = Invoke-RestMethod -Uri $tokenEndpoint -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
                $token = $response.access_token
                $authMethod = "Service Principal (Direct OAuth2)"
                Write-Verbose "ARM token acquired via service principal authentication"
            } catch {
                $tokenAcquisitionErrors += "Service Principal: $($_.Exception.Message)"
            }
        }

        if (-not $token) {
            $errorMessage = @"
Failed to acquire ARM access token for Azure Resource Manager API calls.

Authentication Methods Attempted:
$($tokenAcquisitionErrors | ForEach-Object { "  - $_" } | Out-String)

Recommended GitHub Actions Setup (Official Microsoft Pattern):
1. Use the azure/login@v2 action with OIDC in your workflow:
   
   jobs:
     deploy:
       permissions:
         id-token: write
       steps:
       - uses: azure/login@v2
         with:
           client-id: `${{ secrets.AZURE_CLIENT_ID }}
           tenant-id: `${{ secrets.AZURE_TENANT_ID }}
           subscription-id: `${{ secrets.AZURE_SUBSCRIPTION_ID }}
           enable-AzPSSession: true

2. Configure federated identity credentials in Azure:
   - Issuer: https://token.actions.githubusercontent.com
   - Subject: repo:owner/repo:environment:production (or appropriate pattern)
   - Audience: api://AzureADTokenExchange

Alternative Authentication Methods:
- Set AZURE_ACCESS_TOKEN environment variable with a valid ARM token
- Use service principal with AZURE_CLIENT_ID, AZURE_TENANT_ID, and AZURE_CLIENT_SECRET
- Use managed identity with Connect-AzAccount in your script

Current Environment Variables:
  AZURE_CLIENT_ID: $($null -ne $env:AZURE_CLIENT_ID)
  AZURE_TENANT_ID: $($null -ne $env:AZURE_TENANT_ID)
  AZURE_ACCESS_TOKEN: $($null -ne $env:AZURE_ACCESS_TOKEN)
  AZURE_CLIENT_SECRET: $($null -ne $env:AZURE_CLIENT_SECRET)
  AZURE_CLIENT_ASSERTION: $($null -ne $env:AZURE_CLIENT_ASSERTION)
  Azure PowerShell Context: $(if (Get-AzContext -ErrorAction SilentlyContinue) { "Available" } else { "Not Available" })

For more information: https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect
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
