# Minimal Get-PIMAzureEnvironmentEndpoint for orchestrator use
function Get-PIMAzureEnvironmentEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('ARM', 'MicrosoftGraph')]
        [string]$EndpointType,
        [switch]$NoCache
    )

    # Simple environment detection
    try {
        $ctx = Get-AzContext -ErrorAction SilentlyContinue
        $envName = if ($ctx) { $ctx.Environment.Name } else { 'AzureCloud' }
    } catch {
        $envName = 'AzureCloud'
    }

    # Return appropriate endpoints
    switch ($EndpointType) {
        'ARM' {
            switch ($envName) {
                'AzureUSGovernment' { return 'https://management.usgovcloudapi.net/' }
                'AzureChinaCloud'   { return 'https://management.chinacloudapi.cn/' }
                'AzureGermanCloud'  { return 'https://management.microsoftazure.de/' }
                Default             { return 'https://management.azure.com/' }
            }
        }
        'MicrosoftGraph' {
            switch ($envName) {
                'AzureUSGovernment' { return 'https://graph.microsoft.us' }
                'AzureChinaCloud'   { return 'https://microsoftgraph.chinacloudapi.cn' }
                'AzureGermanCloud'  { return 'https://graph.microsoft.de' }
                Default             { return 'https://graph.microsoft.com' }
            }
        }
    }
}
