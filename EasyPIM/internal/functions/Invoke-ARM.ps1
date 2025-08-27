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
        # Get Azure access token
        $token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com/").Token
        
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
