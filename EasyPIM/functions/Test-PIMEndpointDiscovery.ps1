function Test-PIMEndpointDiscovery {
    <#
    .SYNOPSIS
        Tests EasyPIM's Azure endpoint discovery functionality across different environments

    .DESCRIPTION
        Validates that EasyPIM can correctly discover ARM and Microsoft Graph endpoints
        for the current Azure environment. Useful for troubleshooting multi-cloud scenarios
        and verifying endpoint configuration for Azure Stack or sovereign cloud deployments.

    .PARAMETER EndpointType
        Type of endpoint to test: 'ARM', 'MicrosoftGraph', or 'All'

    .PARAMETER ShowConfiguration
        Display current Azure and Microsoft Graph connection details

    .PARAMETER TestConnection
        Test connectivity to discovered endpoints (requires internet access)

    .EXAMPLE
        Test-PIMEndpointDiscovery
        Tests discovery of both ARM and Microsoft Graph endpoints for current environment
        Use -Verbose for detailed discovery logs and endpoint validation output.

    .EXAMPLE
        Test-PIMEndpointDiscovery -EndpointType ARM -ShowConfiguration
        Tests ARM endpoint discovery and shows Azure configuration details
        Helpful when diagnosing Az context issues in sovereign clouds.

    .EXAMPLE
        Test-PIMEndpointDiscovery -TestConnection
        Tests endpoint discovery and validates connectivity to discovered endpoints
        Runs Test-NetConnection to each host on port 443 and records the results.

    .OUTPUTS
        PSCustomObject containing discovered endpoints and test results

    .NOTES
        This cmdlet helps verify that EasyPIM's multi-cloud support is working correctly.
        It's particularly useful when setting up custom Azure environments or troubleshooting
        connection issues in sovereign clouds.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('ARM', 'MicrosoftGraph', 'All')]
        [string]$EndpointType = 'All',

        [Parameter(Mandatory = $false)]
        [switch]$ShowConfiguration,

        [Parameter(Mandatory = $false)]
        [switch]$TestConnection
    )

    # Handle WhatIf scenario
    if ($PSCmdlet.ShouldProcess("EasyPIM endpoint discovery", "Test endpoint discovery functionality")) {
        # Continue with actual processing
    } else {
        Write-Information "Would test EasyPIM endpoint discovery for: $EndpointType"
        return
    }

    Write-Verbose "Starting EasyPIM endpoint discovery test"

    # Initialize result object
    $result = [PSCustomObject]@{
        Timestamp = Get-Date
        AzureEnvironment = $null
        AzureConnected = $false
        GraphEnvironment = $null
        GraphConnected = $false
        ARMEndpoint = $null
        GraphEndpoint = $null
        EndpointDiscoverySuccess = $false
        ConnectionTestResults = @{}
        Warnings = @()
        Recommendations = @()
    }

    # Main execution block with simple error handling
    Write-Verbose "Checking Azure PowerShell context"
    $azContext = Get-AzContext -ErrorAction SilentlyContinue

    if ($azContext) {
        $result.AzureConnected = $true
        $result.AzureEnvironment = $azContext.Environment.Name

        if ($ShowConfiguration) {
            Write-Host "Azure Configuration:" -ForegroundColor Green
            Write-Host "  Environment: $($azContext.Environment.Name)" -ForegroundColor Gray
            Write-Host "  Account: $($azContext.Account.Id)" -ForegroundColor Gray
            Write-Host "  Tenant: $($azContext.Tenant.Id)" -ForegroundColor Gray
            Write-Host "  Subscription: $($azContext.Subscription.Name) ($($azContext.Subscription.Id))" -ForegroundColor Gray
            Write-Host ""
        }

        # Test ARM endpoint discovery when Azure is connected
        if ($EndpointType -in @('ARM', 'All')) {
            Write-Verbose "Testing ARM endpoint discovery"
            $result.ARMEndpoint = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM' -ErrorAction SilentlyContinue

            if ($result.ARMEndpoint) {
                Write-Host "[OK] ARM Endpoint: $($result.ARMEndpoint)" -ForegroundColor Green

                # Validate ARM endpoint format
                $armFormatValid = ($result.ARMEndpoint -match '^https://management\.' -and $result.ARMEndpoint.EndsWith('/'))
                if ($armFormatValid) {
                    Write-Verbose "ARM endpoint format validation passed"
                }
                else {
                    $result.Warnings += "ARM endpoint format may be invalid: $($result.ARMEndpoint)"
                    Write-Warning "ARM endpoint format unexpected: $($result.ARMEndpoint)"
                }
            }
            else {
                $result.Warnings += "ARM endpoint discovery failed"
                Write-Error "Failed to discover ARM endpoint"
            }
        }
    }
    else {
        $result.Warnings += "No Azure PowerShell context found"
        $result.Recommendations += "Connect to Azure: Connect-AzAccount"
        Write-Warning "No Azure context found. Connect with: Connect-AzAccount"
    }

    # Check Microsoft Graph context
    Write-Verbose "Checking Microsoft Graph context"
    $mgContext = Get-MgContext -ErrorAction SilentlyContinue

    if ($mgContext) {
        $result.GraphConnected = $true
        $result.GraphEnvironment = $mgContext.Environment

        if ($ShowConfiguration) {
            Write-Host "Microsoft Graph Configuration:" -ForegroundColor Green
            Write-Host "  Environment: $($mgContext.Environment)" -ForegroundColor Gray
            Write-Host "  App: $($mgContext.AppName)" -ForegroundColor Gray
            Write-Host "  Scopes: $($mgContext.Scopes -join ', ')" -ForegroundColor Gray
            Write-Host ""
        }
    }
    else {
        $result.Recommendations += "Connect to Microsoft Graph: Connect-MgGraph"
        Write-Verbose "No Microsoft Graph context found"
    }

    # Test Microsoft Graph endpoint discovery
    if ($EndpointType -in @('MicrosoftGraph', 'All')) {
        Write-Verbose "Testing Microsoft Graph endpoint discovery"

        if ($result.AzureConnected) {
            $result.GraphEndpoint = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph' -ErrorAction SilentlyContinue

            if ($result.GraphEndpoint) {
                Write-Host "[OK] Microsoft Graph Endpoint: $($result.GraphEndpoint)" -ForegroundColor Green

                # Validate Graph endpoint format
                if ($result.GraphEndpoint -match '^https://.*graph') {
                    Write-Verbose "Microsoft Graph endpoint format validation passed"
                }
                else {
                    $result.Warnings += "Microsoft Graph endpoint format may be invalid: $($result.GraphEndpoint)"
                    Write-Warning "Microsoft Graph endpoint format unexpected: $($result.GraphEndpoint)"
                }
            }
            else {
                $result.Warnings += "Microsoft Graph endpoint discovery failed"
                Write-Error "Failed to discover Microsoft Graph endpoint"
            }
        }
        else {
            $result.Warnings += "Cannot test Microsoft Graph endpoint discovery without Azure context"
            Write-Warning "Microsoft Graph endpoint discovery requires Azure context"
        }
    }

    # Test connectivity if requested
    if ($TestConnection -and ($result.ARMEndpoint -or $result.GraphEndpoint)) {
        Write-Verbose "Testing endpoint connectivity"
    Write-Host "Testing endpoint connectivity..." -ForegroundColor Yellow

        # Test ARM connectivity
        if ($result.ARMEndpoint) {
            $armTest = Test-NetConnection -ComputerName ([System.Uri]$result.ARMEndpoint).Host -Port 443 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

            if ($armTest -and $armTest.TcpTestSucceeded) {
                $result.ConnectionTestResults['ARM'] = $true
                Write-Host "[OK] ARM endpoint connectivity: Success" -ForegroundColor Green
            }
            else {
                $result.ConnectionTestResults['ARM'] = $false
                $result.Warnings += "ARM connectivity test failed"
                Write-Host "[FAIL] ARM endpoint connectivity: Failed" -ForegroundColor Red
            }
        }

        # Test Graph connectivity
        if ($result.GraphEndpoint) {
            $graphTest = Test-NetConnection -ComputerName ([System.Uri]$result.GraphEndpoint).Host -Port 443 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

            if ($graphTest -and $graphTest.TcpTestSucceeded) {
                $result.ConnectionTestResults['Graph'] = $true
                Write-Host "[OK] Microsoft Graph endpoint connectivity: Success" -ForegroundColor Green
            }
            else {
                $result.ConnectionTestResults['Graph'] = $false
                $result.Warnings += "Microsoft Graph connectivity test failed"
                Write-Host "[FAIL] Microsoft Graph endpoint connectivity: Failed" -ForegroundColor Red
            }
        }
    }

    # Determine overall success
    $discoverySuccess = $true
    if ($EndpointType -in @('ARM', 'All') -and -not $result.ARMEndpoint) {
        $discoverySuccess = $false
    }
    if ($EndpointType -in @('MicrosoftGraph', 'All') -and -not $result.GraphEndpoint) {
        $discoverySuccess = $false
    }

    $result.EndpointDiscoverySuccess = $discoverySuccess

    # Show summary
    Write-Host ""
    Write-Host "Endpoint Discovery Summary:" -ForegroundColor Cyan

    $azureEnvColor = if ($result.AzureEnvironment) { 'Green' } else { 'Yellow' }
    Write-Host "  Azure Environment: $($result.AzureEnvironment)" -ForegroundColor $azureEnvColor

    $graphEnvColor = if ($result.GraphEnvironment) { 'Green' } else { 'Yellow' }
    Write-Host "  Graph Environment: $($result.GraphEnvironment)" -ForegroundColor $graphEnvColor

    $successColor = if ($result.EndpointDiscoverySuccess) { 'Green' } else { 'Red' }
    Write-Host "  Discovery Success: $($result.EndpointDiscoverySuccess)" -ForegroundColor $successColor

    if ($result.Recommendations.Count -gt 0) {
        Write-Host ""
        Write-Host "Recommendations:" -ForegroundColor Yellow
        foreach ($rec in $result.Recommendations) {
            Write-Host "  - $rec" -ForegroundColor Gray
        }
    }

    Write-Verbose "EasyPIM endpoint discovery test completed"

    # Return result object
    return $result
}
