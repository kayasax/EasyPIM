BeforeAll {
    # Import the function
    . "$PSScriptRoot\..\EasyPIM\internal\functions\Get-PIMAzureEnvironmentEndpoint.ps1"
    
    # Check if required modules are available
    $script:AzAccountsAvailable = $null -ne (Get-Module Az.Accounts -ListAvailable)
    $script:MgGraphAvailable = $null -ne (Get-Module Microsoft.Graph.Authentication -ListAvailable)
    
    # Mock functions if modules aren't available
    if (-not $script:AzAccountsAvailable) {
        function Get-AzContext { return $null }
        function Get-AzEnvironment { 
            param($Name)
            if ($Name -eq 'AzureCloud') {
                return @{
                    Name = 'AzureCloud'
                    ResourceManagerUrl = 'https://management.azure.com/'
                    ActiveDirectoryAuthority = 'https://login.microsoftonline.com/'
                    MicrosoftGraphUrl = 'https://graph.microsoft.com/'
                }
            }
            return $null
        }
    }
    
    if (-not $script:MgGraphAvailable) {
        function Get-MgContext { return $null }
        function Get-MgEnvironment { 
            param($Name)
            if ($Name -eq 'Global') {
                return @{
                    Name = 'Global'
                    GraphEndpoint = 'https://graph.microsoft.com'
                }
            }
            return $null
        }
    }
}

Describe "Get-PIMAzureEnvironmentEndpoint" {
    
    BeforeEach {
        # Clear any cached endpoints
        if (Get-Variable -Name 'EndpointCache' -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name 'EndpointCache' -Scope Script
        }
    }
    
    Context "When no Azure context exists" {
        BeforeEach {
            Mock Get-AzContext { $null }
        }
        
        It "Should throw an error for missing context" {
            { Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM' } | Should -Throw "*Azure context required*"
        }
    }
    
    Context "When in Azure Commercial Cloud" {
        BeforeEach {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'AzureCloud'
                        ResourceManagerUrl = 'https://management.azure.com/'
                    }
                }
            }
            
            Mock Get-MgContext {
                @{
                    Environment = 'Global'
                }
            }
            
            Mock Get-MgEnvironment {
                @{
                    GraphEndpoint = 'https://graph.microsoft.com'
                }
            }
        }
        
        It "Should return correct ARM endpoint" {
            $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
            $result | Should -Be 'https://management.azure.com/'
        }
        
        It "Should return correct Microsoft Graph endpoint" {
            $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
            $result | Should -Be 'https://graph.microsoft.com'
        }
        
        It "Should ensure ARM endpoint has trailing slash" {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'AzureCloud'
                        ResourceManagerUrl = 'https://management.azure.com'  # No trailing slash
                    }
                }
            }
            
            $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
            $result | Should -Match '/$'
        }
        
        It "Should ensure Graph endpoint does not have trailing slash" {
            Mock Get-MgEnvironment {
                @{
                    GraphEndpoint = 'https://graph.microsoft.com/'  # With trailing slash
                }
            }
            
            $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
            $result | Should -Not -Match '/$'
        }
    }
    
    Context "When in Azure US Government Cloud" {
        BeforeEach {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'AzureUSGovernment'
                        ResourceManagerUrl = 'https://management.usgovcloudapi.net/'
                    }
                }
            }
            
            Mock Get-MgContext { $null }  # No active Graph session
            
            Mock Get-MgEnvironment -ParameterFilter { $Name -eq 'USGov' } {
                @{
                    GraphEndpoint = 'https://graph.microsoft.us'
                }
            }
        }
        
        It "Should return correct US Government ARM endpoint" {
            $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
            $result | Should -Be 'https://management.usgovcloudapi.net/'
        }
        
        It "Should return correct US Government Graph endpoint" {
            $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
            $result | Should -Be 'https://graph.microsoft.us'
        }
    }
    
    Context "When in Azure China Cloud" {
        BeforeEach {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'AzureChinaCloud'
                        ResourceManagerUrl = 'https://management.chinacloudapi.cn/'
                    }
                }
            }
            
            Mock Get-MgContext { $null }
            
            Mock Get-MgEnvironment -ParameterFilter { $Name -eq 'China' } {
                @{
                    GraphEndpoint = 'https://microsoftgraph.chinacloudapi.cn'
                }
            }
        }
        
        It "Should return correct China Cloud endpoints" {
            Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM' | Should -Be 'https://management.chinacloudapi.cn/'
            Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph' | Should -Be 'https://microsoftgraph.chinacloudapi.cn'
        }
    }
    
    Context "When using custom environment with environment variable" {
        BeforeEach {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'AzureStackProd'
                        ResourceManagerUrl = 'https://management.azurestack.contoso.com/'
                        ActiveDirectoryAuthority = 'https://login.azurestack.contoso.com/'
                    }
                }
            }
            
            Mock Get-MgContext { $null }
            Mock Get-MgEnvironment { $null }  # No matching Graph environment
            
            # Mock environment variable
            Mock Get-ChildItem { @() } -ParameterFilter { $Path -eq 'Env:EASYPIM_GRAPH_ENDPOINT_*' }
            $env:EASYPIM_GRAPH_ENDPOINT_AZURESTACKPROD = 'https://graph.azurestack.contoso.com'
        }
        
        AfterEach {
            Remove-Item Env:EASYPIM_GRAPH_ENDPOINT_AZURESTACKPROD -ErrorAction SilentlyContinue
        }
        
        It "Should return custom ARM endpoint" {
            $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
            $result | Should -Be 'https://management.azurestack.contoso.com/'
        }
        
        It "Should return Graph endpoint from environment variable" {
            $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
            $result | Should -Be 'https://graph.azurestack.contoso.com'
        }
    }
    
    Context "NoCache functionality" {
        BeforeEach {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'AzureUSGovernment'
                        ResourceManagerUrl = 'https://management.usgovcloudapi.net/'
                        ActiveDirectoryAuthority = 'https://login.microsoftonline.us/'
                    }
                }
            }
            
            Mock Get-MgContext { $null }
            Mock Get-MgEnvironment { 
                @{
                    Name = 'USGov'
                    GraphEndpoint = 'https://graph.microsoft.us'
                }
            }
        }
        
        It "Should bypass cache when NoCache is specified" {
            # First call should populate cache
            $result1 = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
            $result1 | Should -Be 'https://graph.microsoft.us'
            
            # Second call with NoCache should still work
            $result2 = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph' -NoCache
            $result2 | Should -Be 'https://graph.microsoft.us'
        }
    }
        BeforeEach {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'AzureStackProd'
                        ResourceManagerUrl = 'https://management.azurestack.contoso.com/'
                        ActiveDirectoryAuthority = 'https://login.azurestack.contoso.com/'
                    }
                }
            }
            
            Mock Get-MgContext { $null }
            Mock Get-MgEnvironment { $null }
            
            # Mock environment variable
            $env:EASYPIM_GRAPH_ENDPOINT_AZURESTACKPROD = 'https://graph.env.azurestack.com'
        }
        
        AfterEach {
            # Cleanup environment variable
            if (Test-Path Env:\EASYPIM_GRAPH_ENDPOINT_AZURESTACKPROD) {
                Remove-Item Env:\EASYPIM_GRAPH_ENDPOINT_AZURESTACKPROD
            }
        }
        
        It "Should use environment variable for Graph endpoint" {
            $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
            $result | Should -Be 'https://graph.env.azurestack.com'
        }
    }
    
    Context "When using custom environment with pattern inference" {
        BeforeEach {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'CustomAzureStack'
                        ResourceManagerUrl = 'https://management.local.azurestack.external/'
                        ActiveDirectoryAuthority = 'https://login.local.azurestack.external/'
                    }
                }
            }
            
            Mock Get-MgContext { $null }
            Mock Get-MgEnvironment { $null }
        }
        
        It "Should infer Graph endpoint from Azure Stack pattern" {
            $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
            $result | Should -Be 'https://graph.local.azurestack.external'
        }
    }
    
    Context "When discovery fails for custom environment" {
        BeforeEach {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'UnknownCustom'
                        ResourceManagerUrl = 'https://management.unknown.cloud/'
                        ActiveDirectoryAuthority = 'https://login.unknown.cloud/'
                    }
                }
            }
            
            Mock Get-MgContext { $null }
            Mock Get-MgEnvironment { $null }
            Mock Test-Path { $false }
            Mock Write-Warning {} -Verifiable
        }
        
        It "Should throw error instead of fallback for unknown environments" {
            { Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph' } | Should -Throw "*Could not determine Microsoft Graph endpoint*"
        }
    }
    
    Context "Caching behavior" {
        BeforeEach {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'AzureCloud'
                        ResourceManagerUrl = 'https://management.azure.com/'
                    }
                }
            }
            
            Mock Get-MgContext { $null }
            Mock Get-MgEnvironment {
                @{
                    GraphEndpoint = 'https://graph.microsoft.com'
                }
            }
        }
        
        It "Should cache Microsoft Graph endpoint after first call" {
            # First call - should invoke Get-MgEnvironment
            $result1 = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
            
            # Second call - should use cache
            $result2 = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
            
            $result1 | Should -Be $result2
            Should -Invoke Get-MgEnvironment -Times 1 -Exactly
        }
        
        It "Should not cache ARM endpoints" {
            # ARM endpoints should always be retrieved fresh from context
            Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM' | Out-Null
            Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM' | Out-Null
            
            Should -Invoke Get-AzContext -Times 2 -Exactly
        }
    }
    
    Context "Error handling" {
        It "Should handle Get-AzContext errors gracefully" {
            Mock Get-AzContext { throw "Connection error" }
            
            { Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM' } | Should -Throw "*Connection error*"
        }
        
        It "Should handle Get-MgEnvironment errors gracefully" {
            Mock Get-AzContext {
                @{
                    Environment = @{
                        Name = 'AzureCloud'
                        ResourceManagerUrl = 'https://management.azure.com/'
                        ActiveDirectoryAuthority = 'https://login.microsoftonline.com/'        
                    }
                }
            }

            Mock Get-MgContext { $null }
            Mock Get-MgEnvironment { throw "Graph error" }
            Mock Write-Warning {}

            $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
            $result | Should -Be 'https://graph.microsoft.com'  # Should fallback
        }
    }