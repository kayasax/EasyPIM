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
        $SubscriptionId
    )

    try {
        # Get Azure access token with OIDC compatibility
        $azContext = Get-AzContext -ErrorAction Stop
        if (-not $azContext) {
            throw "No Azure context available. Please run Connect-AzAccount first."
        }
        
        # Try multiple token acquisition methods for OIDC compatibility
        $tokenObj = $null
        $tokenAcquisitionErrors = @()
        
        # Method 1: Standard ARM resource token
        try {
            $tokenObj = Get-AzAccessToken -ResourceUrl "https://management.azure.com/" -ErrorAction Stop
            Write-Verbose "ARM token acquired via standard method"
        } catch {
            $tokenAcquisitionErrors += "Standard method: $($_.Exception.Message)"
        }
        
        # Method 2: Default token (for OIDC scenarios)
        if (-not $tokenObj) {
            try {
                $tokenObj = Get-AzAccessToken -ErrorAction Stop
                Write-Verbose "ARM token acquired via default method (OIDC compatible)"
            } catch {
                $tokenAcquisitionErrors += "Default method: $($_.Exception.Message)"
            }
        }
        
        if (-not $tokenObj) {
            $errorMessage = "Failed to acquire ARM access token. Errors: " + ($tokenAcquisitionErrors -join "; ")
            throw $errorMessage
        }

        # Handle SecureString token conversion
        if ($tokenObj.Token -is [System.Security.SecureString]) {
            $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenObj.Token))
        } else {
            $token = $tokenObj.Token
        }

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
