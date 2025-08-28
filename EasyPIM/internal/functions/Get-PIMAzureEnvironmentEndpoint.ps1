<#
.SYNOPSIS
Get Azure environment endpoint URLs

.DESCRIPTION
Returns the appropriate endpoint URLs for different Azure environments (commercial, government, China, Germany)

.PARAMETER EndpointType
The type of endpoint to retrieve - ARM or MicrosoftGraph

.PARAMETER NoCache
Switch to disable caching (included for compatibility but not used in this implementation)

.EXAMPLE
Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'

.EXAMPLE
Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'

.NOTES
Author: Loïc MICHEL
Homepage: https://github.com/kayasax/EasyPIM
#>
function Get-PIMAzureEnvironmentEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('ARM', 'MicrosoftGraph')]
        [string]$EndpointType,
        [switch]$NoCache
    )

    # Detect Azure environment from current context
    try {
        $ctx = Get-AzContext -ErrorAction SilentlyContinue
        $envName = if ($ctx) { $ctx.Environment.Name } else { 'AzureCloud' }
    } catch {
        Write-Verbose "Could not determine Azure context, defaulting to AzureCloud"
        $envName = 'AzureCloud'
    }

    # Return appropriate endpoints based on environment
    switch ($EndpointType) {
        'ARM' {
            switch ($envName) {
                'AzureUSGovernment' {
                    Write-Verbose "Using US Government ARM endpoint"
                    return 'https://management.usgovcloudapi.net/'
                }
                'AzureChinaCloud' {
                    Write-Verbose "Using China Cloud ARM endpoint"
                    return 'https://management.chinacloudapi.cn/'
                }
                'AzureGermanCloud' {
                    Write-Verbose "Using German Cloud ARM endpoint"
                    return 'https://management.microsoftazure.de/'
                }
                Default {
                    Write-Verbose "Using public Azure ARM endpoint"
                    return 'https://management.azure.com/'
                }
            }
        }
        'MicrosoftGraph' {
            switch ($envName) {
                'AzureUSGovernment' {
                    Write-Verbose "Using US Government Graph endpoint"
                    return 'https://graph.microsoft.us'
                }
                'AzureChinaCloud' {
                    Write-Verbose "Using China Cloud Graph endpoint"
                    return 'https://microsoftgraph.chinacloudapi.cn'
                }
                'AzureGermanCloud' {
                    Write-Verbose "Using German Cloud Graph endpoint"
                    return 'https://graph.microsoft.de'
                }
                Default {
                    Write-Verbose "Using public Azure Graph endpoint"
                    return 'https://graph.microsoft.com'
                }
            }
        }
    }
}
