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
    } catch { }

    $graph = "$graphBase/$version/"
    $uri = $graph + $Endpoint

    if ($Filter) {
        $uri += if ($uri -like "*?*") { "&`$filter=$Filter" } else { "?`$filter=$Filter" }
    }

    try {
        $response = Invoke-MgGraphRequest -Uri $uri -Method $Method -Body $body
        return $response
    } catch {
        Write-Error "Graph API call failed: $($_.Exception.Message)"
        throw
    }
}
