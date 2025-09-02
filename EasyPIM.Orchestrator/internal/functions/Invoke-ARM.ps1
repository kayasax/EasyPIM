# Minimal Invoke-ARM for orchestrator use
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

        $response = Invoke-RestMethod @params
        return $response
    } catch {
        Write-Error "ARM API call failed: $($_.Exception.Message)"
        throw
    }
}
