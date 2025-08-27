function Test-PIMEndpointDiscovery {
    [CmdletBinding()]
    param(
        [switch]$NoCache
    )

function Test-PIMEndpointDiscovery {
    [CmdletBinding()]
    param(
        [switch]$NoCache
    )

    # Check Azure PowerShell connection (gracefully handle missing Az module)
    try {
        if (Get-Command Get-AzContext -ErrorAction SilentlyContinue) {
            $az = Get-AzContext -ErrorAction SilentlyContinue
            if (-not $az) { 
                Write-Host "Azure: Not connected (use Connect-AzAccount)" -ForegroundColor Yellow 
            } else { 
                Write-Host "Azure: $($az.Environment.Name)" -ForegroundColor Green 
            }
        } else {
            Write-Host "Azure: Az module not available" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Azure: Not available ($($_.Exception.Message))" -ForegroundColor Gray
    }

    # Check Microsoft Graph connection (gracefully handle missing module)
    try {
        if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
            $mg = Get-MgContext -ErrorAction SilentlyContinue
            if (-not $mg) { 
                Write-Host "Graph: Not connected (use Connect-MgGraph)" -ForegroundColor Yellow 
            } else { 
                Write-Host "Graph: $($mg.Environment)" -ForegroundColor Green 
            }
        } else {
            Write-Host "Graph: Microsoft.Graph module not available" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Graph: Not available ($($_.Exception.Message))" -ForegroundColor Gray
    }

    # Show endpoint discovery (this should work without external dependencies)
    try {
        $arm = Get-PIMAzureEnvironmentEndpoint -EndpointType ARM -NoCache:$NoCache
        $grf = Get-PIMAzureEnvironmentEndpoint -EndpointType MicrosoftGraph -NoCache:$NoCache
        Write-Host "ARM:   $arm" -ForegroundColor Cyan
        Write-Host "Graph: $grf" -ForegroundColor Cyan
    } catch {
        Write-Warning "Endpoint discovery failed: $($_.Exception.Message)"
        # Don't throw in CI environments - just show the error
        if ($env:GITHUB_ACTIONS) {
            Write-Host "Note: Endpoint discovery may require authentication in runtime environments" -ForegroundColor Gray
        } else {
            throw
        }
    }
}
