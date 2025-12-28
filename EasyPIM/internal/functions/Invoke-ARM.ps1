<#
.SYNOPSIS
Invoke Azure Resource Manager (ARM) API calls

.DESCRIPTION
Core function for making Azure Resource Manager API requests with proper authentication

.PARAMETER restURI
The ARM REST API URI to call

.PARAMETER method
HTTP method (GET, POST, PUT, PATCH, DELETE)

.PARAMETER body
Request body for POST/PUT/PATCH operations

.PARAMETER SubscriptionId
Azure subscription ID for scoped operations

.EXAMPLE
Invoke-ARM -restURI "https://management.azure.com/subscriptions/..." -method GET

.NOTES
Author: Loïc MICHEL
Homepage: https://github.com/kayasax/EasyPIM
#>
function Invoke-ARM {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $restURI,

        [Parameter(Position = 1)]
        [System.String]
        $method,

        [Parameter(Position = 2)]
        [System.String]
        $body = "",

        [Parameter(Position = 3)]
        [System.String]
        $SubscriptionId,

        [Parameter(Position = 4)]
        [System.String]
        $TenantId
    )

    try {
        # Enhanced OIDC-compatible ARM token acquisition with GitHub Actions prioritization
        $token = $null
        $tokenAcquisitionErrors = @()
        $authMethod = "Unknown"

        # Method 0: Specific Context via PowerShell (PRIORITIZED when Tenant/Subscription specified)
        # If the user explicitly requested a specific Tenant or Subscription, we prioritize the PowerShell context
        # because it's the most likely to have the correct session for that specific scope.
        if (-not $token -and ($SubscriptionId -or $TenantId)) {
            try {
                $azContext = $null
                if ($SubscriptionId) {
                    $azContext = Get-AzContext -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue
                }
                if (-not $azContext -and $TenantId) {
                     $azContext = Get-AzContext -List | Where-Object { $_.Tenant.Id -eq $TenantId } | Select-Object -First 1
                }

                # If we found a context matching the request, use it
                if ($azContext) {
                    $tokenParams = @{
                        ResourceUrl = "https://management.azure.com/"
                        ErrorAction = "Stop"
                    }
                    if ($azContext.Tenant.Id) { $tokenParams["TenantId"] = $azContext.Tenant.Id }

                    $tokenObj = Get-AzAccessToken @tokenParams
                    $token = if ($tokenObj.Token -is [System.Security.SecureString]) {
                        if ($PSVersionTable.PSVersion.Major -ge 7) {
                            ConvertFrom-SecureString -SecureString $tokenObj.Token -AsPlainText
                        } else {
                            try {
                                [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenObj.Token))
                            } catch {
                                $encryptedToken = ConvertFrom-SecureString -SecureString $tokenObj.Token -Force
                                $secureToken = ConvertTo-SecureString -String $encryptedToken -Force
                                [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken))
                            }
                        }
                    } else {
                        $tokenObj.Token
                    }
                    $authMethod = "Azure PowerShell (Specific Context)"
                    Write-Verbose "ARM token acquired from Azure PowerShell for specific context ($($azContext.Name))"
                }
            } catch {
                $tokenAcquisitionErrors += "PowerShell Specific Context: $($_.Exception.Message)"
            }
        }

        # Method 1: Environment Variables (PRIORITIZED - Works best in GitHub Actions OIDC)
        # This method is prioritized because it's the most reliable in CI/CD environments
        if (-not $token -and ($env:AZURE_ACCESS_TOKEN -or $env:ARM_ACCESS_TOKEN)) {
            try {
                $token = $env:AZURE_ACCESS_TOKEN -or $env:ARM_ACCESS_TOKEN
                $authMethod = "Environment Variable (AZURE_ACCESS_TOKEN)"
                Write-Verbose "ARM token acquired from environment variable - GitHub Actions OIDC compatible"
            } catch {
                $tokenAcquisitionErrors += "Environment variable: $($_.Exception.Message)"
            }
        }

        # Method 2: Azure CLI (HIGHLY RELIABLE - Works with azure/login@v2 OIDC)
        # Azure CLI tokens work consistently with GitHub Actions OIDC setup
        if (-not $token) {
            try {
                # Check if Azure CLI is available and authenticated
                $cliCheck = az account show --query id --output tsv 2>$null
                if ($cliCheck) {
                    # Build CLI command with specific context if requested
                    $cliArgs = @("account", "get-access-token", "--resource", "https://management.azure.com/", "--query", "accessToken", "--output", "tsv")

                    # Only append subscription/tenant if we haven't already found a token (which we haven't if we are here)
                    # and if they are provided.
                    if ($SubscriptionId) {
                        $cliArgs += "--subscription"
                        $cliArgs += $SubscriptionId
                    } elseif ($TenantId) {
                        $cliArgs += "--tenant"
                        $cliArgs += $TenantId
                    }

                    $cliToken = az @cliArgs 2>$null
                    if ($cliToken -and $cliToken.Trim() -ne "") {
                        $token = $cliToken.Trim()
                        $authMethod = "Azure CLI (GitHub Actions OIDC Compatible)"
                        Write-Verbose "ARM token acquired from Azure CLI - works reliably with azure/login@v2"
                    } else {
                        # Don't throw here, just let it fall through to next method
                        Write-Verbose "Azure CLI returned empty token"
                    }
                } else {
                    # Don't throw here
                    Write-Verbose "Azure CLI not authenticated"
                }
            } catch {
                $tokenAcquisitionErrors += "Azure CLI: $($_.Exception.Message)"
            }
        }

        # Method 3: Azure PowerShell Context (May fail in some GitHub Actions environments)
        # Keep this as fallback since it can be unreliable with OIDC in some configurations
        if (-not $token) {
            try {
                $azContext = $null
                if ($SubscriptionId) {
                    # Try to get context for the specific subscription to ensure correct TenantId
                    $azContext = Get-AzContext -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue
                }

                # If no subscription context found (or not provided), try TenantId
                if (-not $azContext -and $TenantId) {
                     # Try to find a context for this tenant
                     $azContext = Get-AzContext -List | Where-Object { $_.Tenant.Id -eq $TenantId } | Select-Object -First 1
                }

                if (-not $azContext) {
                    $azContext = Get-AzContext -ErrorAction Stop
                }

                if ($azContext -and $azContext.Account) {
                    # Use Get-AzAccessToken for ARM resource (recommended approach)
                    $tokenParams = @{
                        ResourceUrl = "https://management.azure.com/"
                        ErrorAction = "Stop"
                    }

                    # CRITICAL FIX: Explicitly use the TenantId from the context to avoid cross-tenant token issues
                    if ($azContext.Tenant.Id) {
                        $tokenParams["TenantId"] = $azContext.Tenant.Id
                    } elseif ($TenantId) {
                        $tokenParams["TenantId"] = $TenantId
                    }

                    $tokenObj = Get-AzAccessToken @tokenParams
                    $token = if ($tokenObj.Token -is [System.Security.SecureString]) {
                        # PowerShell version-aware SecureString conversion
                        if ($PSVersionTable.PSVersion.Major -ge 7) {
                            # PowerShell 7.x: Use ConvertFrom-SecureString -AsPlainText (recommended)
                            ConvertFrom-SecureString -SecureString $tokenObj.Token -AsPlainText
                        } else {
                            # PowerShell 5.1: Use Marshal approach with -Force to avoid prompts
                            try {
                                [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenObj.Token))
                            } catch {
                                # Fallback: Convert to encrypted string then back (less secure but compatible)
                                $encryptedToken = ConvertFrom-SecureString -SecureString $tokenObj.Token -Force
                                $secureToken = ConvertTo-SecureString -String $encryptedToken -Force
                                [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken))
                            }
                        }
                    } else {
                        $tokenObj.Token
                    }
                    $authMethod = "Azure PowerShell Context (Fallback)"
                    Write-Verbose "ARM token acquired from Azure PowerShell context"
                }
            } catch {
                $tokenAcquisitionErrors += "Azure PowerShell Context: $($_.Exception.Message)"
            }
        }

        # Method 4: Service Principal Authentication (Fallback)
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

        # Handle SecureString token conversion (no longer needed as we handle it above)
        # Token is already a string at this point

        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type'  = 'application/json'
        }

        $params = @{
            Uri     = $restURI
            Method  = $method
            Headers = $headers
        }

        if ($body -and $body -ne "") {
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
