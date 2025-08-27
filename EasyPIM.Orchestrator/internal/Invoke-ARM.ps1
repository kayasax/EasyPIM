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
        $headers = @{
            'Authorization' = "Bearer $((Get-AzAccessToken).Token)"
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
