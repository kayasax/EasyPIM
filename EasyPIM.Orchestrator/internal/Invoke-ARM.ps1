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
        # Get Azure access token
        $tokenObj = Get-AzAccessToken -ResourceUrl "https://management.azure.com/"
        
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
