# Test script to validate multi-cloud support improvements
Write-Host "Testing multi-cloud environment support..." -ForegroundColor Green

# Import the function
. "$PSScriptRoot\EasyPIM\internal\functions\Get-PIMAzureEnvironmentEndpoint.ps1"

# Test current environment detection
Write-Host "`n1. Testing current environment detection:" -ForegroundColor Yellow
try {
    $currentContext = Get-AzContext
    if ($currentContext) {
        Write-Host "Current environment: $($currentContext.Environment.Name)" -ForegroundColor Cyan
        
        # Test ARM endpoint
        $armEndpoint = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM' -Verbose
        Write-Host "ARM endpoint: $armEndpoint" -ForegroundColor Green
        
        # Test Graph endpoint
        $graphEndpoint = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph' -Verbose
        Write-Host "Graph endpoint: $graphEndpoint" -ForegroundColor Green
        
        # Test NoCache functionality
        Write-Host "`n2. Testing NoCache functionality:" -ForegroundColor Yellow
        $graphEndpointNoCache = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph' -NoCache -Verbose
        Write-Host "Graph endpoint (NoCache): $graphEndpointNoCache" -ForegroundColor Green
        
        # Validate endpoints match environment
        Write-Host "`n3. Validating endpoint-environment match:" -ForegroundColor Yellow
        $envName = $currentContext.Environment.Name
        
        # Test validation function
        $armValid = Test-EndpointEnvironmentMatch -Endpoint $armEndpoint -EnvironmentName $envName -Verbose
        Write-Host "ARM endpoint validation: $armValid" -ForegroundColor $(if($armValid) {"Green"} else {"Red"})
        
        $graphValid = Test-EndpointEnvironmentMatch -Endpoint $graphEndpoint -EnvironmentName $envName -Verbose  
        Write-Host "Graph endpoint validation: $graphValid" -ForegroundColor $(if($graphValid) {"Green"} else {"Red"})
        
    } else {
        Write-Host "No Azure context found. Please run Connect-AzAccount first." -ForegroundColor Red
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nMulti-cloud test completed!" -ForegroundColor Green
