# Minimal invoke-graph for orchestrator use - duplicated to avoid module scoping issues
function invoke-graph {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]$Endpoint,
        [String]$Method = "GET",
        [String]$version = "v1.0",
        [String]$body,
        [String]$Filter,
        [switch]$NoPagination
    )

    # Simple fallback to global Graph endpoint
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
        Write-Debug "Failed to determine Azure environment, using default Microsoft Graph endpoint"
    }

    $graph = "$graphBase/$version/"
    $uri = $graph + $Endpoint

    if ($Filter) {
        $uri += if ($uri -like "*?*") { "&`$filter=$Filter" } else { "?`$filter=$Filter" }
    }

    try {
        Write-Verbose "Making Graph API call: $Method $uri"
        
        # Only include -Body parameter if we actually have body content
        # This prevents PS5.1 from sending empty body with GET requests
        if ($body) {
            $response = Invoke-MgGraphRequest -Uri $uri -Method $Method -Body $body -ErrorAction Stop
        } else {
            $response = Invoke-MgGraphRequest -Uri $uri -Method $Method -ErrorAction Stop
        }
        
        Write-Verbose "Graph API call successful"
        return $response
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Verbose "Graph API call failed: $errorMessage"
        
        # Preserve the original exception for proper error handling upstream
        if ($_.Exception.Response) {
            Write-Debug "HTTP Status: $($_.Exception.Response.StatusCode)"
            Write-Debug "HTTP Status Description: $($_.Exception.Response.StatusDescription)"
        }
        
        # Re-throw the original exception to maintain compatibility
        throw
    }
}
