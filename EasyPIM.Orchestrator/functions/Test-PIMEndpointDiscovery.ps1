function Test-PIMEndpointDiscovery {
    [CmdletBinding()]
    param(
        [switch]$NoCache
    )

    $az = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $az) { Write-Host "Azure: Not connected (use Connect-AzAccount)" -ForegroundColor Yellow } else { Write-Host "Azure: $($az.Environment.Name)" -ForegroundColor Green }
    $mg = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $mg) { Write-Host "Graph: Not connected (use Connect-MgGraph)" -ForegroundColor Yellow } else { Write-Host "Graph: $($mg.Environment)" -ForegroundColor Green }

    try {
        $arm = Get-PIMAzureEnvironmentEndpoint -EndpointType ARM -NoCache:$NoCache
        $grf = Get-PIMAzureEnvironmentEndpoint -EndpointType MicrosoftGraph -NoCache:$NoCache
        Write-Host "ARM:   $arm" -ForegroundColor Cyan
        Write-Host "Graph: $grf" -ForegroundColor Cyan
    } catch {
        Write-Warning "Endpoint discovery failed: $($_.Exception.Message)"
        throw
    }
}
