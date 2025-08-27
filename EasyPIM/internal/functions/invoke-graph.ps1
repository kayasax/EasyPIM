<#
.SYNOPSIS
Invoke Microsoft Graph API calls

.DESCRIPTION
Core function for making Microsoft Graph API requests with proper authentication and environment support

.PARAMETER Endpoint
The Graph API endpoint to call

.PARAMETER Method
HTTP method (GET, POST, PUT, PATCH, DELETE)

.PARAMETER version
Graph API version (v1.0 or beta)

.PARAMETER body
Request body for POST/PUT/PATCH operations

.PARAMETER Filter
OData filter parameter

.PARAMETER NoPagination
Disable automatic pagination

.EXAMPLE
invoke-graph -Endpoint "users" -Method GET

.NOTES
Author: Loïc MICHEL
Homepage: https://github.com/kayasax/EasyPIM
#>
function invoke-graph {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter()]
        [String]
        $Endpoint,
        [String]
        $Method = "GET",
        [String]
        $version = "v1.0",
        [String]
        $body,
        [String]
        $Filter,
        [switch]
        $NoPagination
    )

    # Determine correct Graph endpoint based on Azure environment
    $graphBase = 'https://graph.microsoft.com'
    try {
        $ctx = Get-AzContext -ErrorAction SilentlyContinue
        if ($ctx) {
            switch ($ctx.Environment.Name) {
                'AzureUSGovernment' { $graphBase = 'https://graph.microsoft.us' }
                'AzureChinaCloud'   { $graphBase = 'https://microsoftgraph.chinacloudapi.cn' }
                'AzureGermanCloud'  { $graphBase = 'https://graph.microsoft.de' }
                Default             { $graphBase = 'https://graph.microsoft.com' }
            }
        }
    } catch {
        Write-Warning "Could not determine Azure context, using default Graph endpoint"
    }

    $graph = "$graphBase/$version/"
    $uri = $graph + $Endpoint

    if ($Filter) {
        $uri += if ($uri -like "*?*") { "&`$filter=$Filter" } else { "?`$filter=$Filter" }
    }

    try {
        $response = Invoke-MgGraphRequest -Uri $uri -Method $Method -Body $body

        # Handle pagination if enabled and response contains @odata.nextLink
        if (-not $NoPagination -and $response.'@odata.nextLink') {
            $allResults = @()
            if ($response.value) {
                $allResults += $response.value
            } else {
                $allResults += $response
            }

            $nextLink = $response.'@odata.nextLink'
            while ($nextLink) {
                $nextResponse = Invoke-MgGraphRequest -Uri $nextLink -Method GET
                if ($nextResponse.value) {
                    $allResults += $nextResponse.value
                } else {
                    $allResults += $nextResponse
                }
                $nextLink = $nextResponse.'@odata.nextLink'
            }

            return @{ value = $allResults }
        }

        return $response
    } catch {
        Write-Error "Graph API call failed: $($_.Exception.Message)"
        throw
    }
}
