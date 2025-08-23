# Test-PIMEndpointDiscovery.Tests.ps1
# Pester tests for Test-PIMEndpointDiscovery function

BeforeAll {
    # Import the module to test
    $ModulePath = "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1"
    if (Test-Path $ModulePath) {
        Import-Module $ModulePath -Force
    }
    
    # Define test environments for validation
    $script:TestEnvironments = @{
        'AzureCloud' = @{
            Name = 'AzureCloud'
            ExpectedArmEndpoint = 'https://management.azure.com/'
            ExpectedGraphEndpoint = 'https://graph.microsoft.com'
        }
        'AzureUSGovernment' = @{
            Name = 'AzureUSGovernment'
            ExpectedArmEndpoint = 'https://management.usgovcloudapi.net/'
            ExpectedGraphEndpoint = 'https://graph.microsoft.us'
        }
        'AzureChinaCloud' = @{
            Name = 'AzureChinaCloud'
            ExpectedArmEndpoint = 'https://management.chinacloudapi.cn/'
            ExpectedGraphEndpoint = 'https://microsoftgraph.chinacloudapi.cn'
        }
        'AzureGermanCloud' = @{
            Name = 'AzureGermanCloud'
            ExpectedArmEndpoint = 'https://management.microsoftazure.de/'
            ExpectedGraphEndpoint = 'https://graph.microsoft.de'
        }
    }
}

Describe "Test-PIMEndpointDiscovery Function Tests" {
    
    Context "Function Availability" {
        It "Should be available as an exported function" {
            $Command = Get-Command Test-PIMEndpointDiscovery -ErrorAction SilentlyContinue
            $Command | Should -Not -BeNullOrEmpty
            $Command.CommandType | Should -Be 'Function'
        }
        
        It "Should have proper help documentation" {
            $Help = Get-Help Test-PIMEndpointDiscovery -ErrorAction SilentlyContinue
            $Help | Should -Not -BeNullOrEmpty
            $Help.Synopsis | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Parameter Validation" {
        It "Should accept valid EndpointType parameter values" {
            $ValidEndpointTypes = @('ARM', 'MicrosoftGraph', 'All')
            foreach ($Type in $ValidEndpointTypes) {
                { Test-PIMEndpointDiscovery -EndpointType $Type -WhatIf } | Should -Not -Throw
            }
        }
        
        It "Should reject invalid EndpointType parameter values" {
            { Test-PIMEndpointDiscovery -EndpointType 'InvalidType' -WhatIf } | Should -Throw
        }
        
        It "Should accept ShowConfiguration switch parameter" {
            { Test-PIMEndpointDiscovery -ShowConfiguration -WhatIf } | Should -Not -Throw
        }
        
        It "Should accept TestConnection switch parameter" {
            { Test-PIMEndpointDiscovery -TestConnection -WhatIf } | Should -Not -Throw
        }
        
        It "Should accept combinations of parameters" {
            { Test-PIMEndpointDiscovery -EndpointType 'All' -ShowConfiguration -TestConnection -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Return Value Structure" {
        BeforeEach {
            # Mock the internal functions to avoid requiring actual Azure connections
            Mock Get-PIMAzureEnvironmentEndpoint {
                if ($EndpointType -eq 'ARM') {
                    return 'https://management.azure.com/'
                } elseif ($EndpointType -eq 'MicrosoftGraph') {
                    return 'https://graph.microsoft.com'
                }
            } -ModuleName EasyPIM
        }
        
        It "Should return an object with required properties" {
            $Result = Test-PIMEndpointDiscovery -EndpointType 'All'
            
            $Result | Should -Not -BeNullOrEmpty
            $Result.PSObject.Properties.Name | Should -Contain 'AzureEnvironment'
            $Result.PSObject.Properties.Name | Should -Contain 'ARMEndpoint'
            $Result.PSObject.Properties.Name | Should -Contain 'GraphEndpoint'
            $Result.PSObject.Properties.Name | Should -Contain 'EndpointDiscoverySuccess'
        }
        
        It "Should include connectivity test results when TestConnection is specified" {
            # Mock connectivity tests
            Mock Test-NetConnection { return @{ TcpTestSucceeded = $true } } -ModuleName EasyPIM
            
            $Result = Test-PIMEndpointDiscovery -EndpointType 'All' -TestConnection
            
            $Result.ConnectionTestResults | Should -Not -BeNullOrEmpty
        }
        
        It "Should include detailed information when ShowConfiguration is specified" {
            $Result = Test-PIMEndpointDiscovery -EndpointType 'All' -ShowConfiguration
            
            $Result | Should -Not -BeNullOrEmpty
            # Should contain additional detail properties when implemented
        }
    }
    
    Context "Environment Detection" {
        BeforeEach {
            # Mock Azure context functions
            Mock Get-AzContext { return $null } -ModuleName EasyPIM
            Mock Get-MgContext { return $null } -ModuleName EasyPIM
        }
        
        It "Should handle missing Azure context gracefully" {
            { Test-PIMEndpointDiscovery } | Should -Not -Throw
        }
        
        It "Should provide helpful warnings when contexts are missing" {
            $WarningMessages = @()
            $null = Test-PIMEndpointDiscovery -WarningVariable WarningMessages
            
            # Should generate warnings about missing contexts
            $WarningMessages.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Error Handling" {
        It "Should handle Get-PIMAzureEnvironmentEndpoint failures gracefully" {
            Mock Get-PIMAzureEnvironmentEndpoint { throw "Mock error" } -ModuleName EasyPIM
            
            $Result = Test-PIMEndpointDiscovery -EndpointType 'All' -ErrorAction SilentlyContinue
            $Result | Should -Not -BeNullOrEmpty
            $Result.EndpointDiscoverySuccess | Should -Be $false
        }
        
        It "Should provide meaningful error messages" {
            Mock Get-PIMAzureEnvironmentEndpoint { throw "Mock connection error" } -ModuleName EasyPIM
            
            $null = Test-PIMEndpointDiscovery -EndpointType 'All' -ErrorVariable ErrorMessages -ErrorAction SilentlyContinue
            
            $ErrorMessages | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Connectivity Testing" {
        BeforeEach {
            Mock Get-PIMAzureEnvironmentEndpoint {
                if ($EndpointType -eq 'ARM') {
                    return 'https://management.azure.com/'
                } elseif ($EndpointType -eq 'MicrosoftGraph') {
                    return 'https://graph.microsoft.com'
                }
            } -ModuleName EasyPIM
        }
        
        It "Should test ARM endpoint connectivity when requested" {
            Mock Test-NetConnection { return @{ TcpTestSucceeded = $true } } -ModuleName EasyPIM
            
            $Result = Test-PIMEndpointDiscovery -EndpointType 'ARM' -TestConnection
            
            $Result.ConnectionTestResults | Should -Not -BeNullOrEmpty
        }
        
        It "Should test Graph endpoint connectivity when requested" {
            Mock Test-NetConnection { return @{ TcpTestSucceeded = $true } } -ModuleName EasyPIM
            
            $Result = Test-PIMEndpointDiscovery -EndpointType 'MicrosoftGraph' -TestConnection
            
            $Result.ConnectionTestResults | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle connectivity test failures" {
            Mock Test-NetConnection { return @{ TcpTestSucceeded = $false } } -ModuleName EasyPIM
            
            $Result = Test-PIMEndpointDiscovery -EndpointType 'All' -TestConnection
            
            $Result.ConnectionTestResults | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Integration with Get-PIMAzureEnvironmentEndpoint" {
        It "Should call Get-PIMAzureEnvironmentEndpoint" {
            Mock Get-PIMAzureEnvironmentEndpoint { return 'https://management.azure.com/' } -ModuleName EasyPIM -Verifiable
            
            Test-PIMEndpointDiscovery -EndpointType 'All'
            
            Should -InvokeVerifiable
        }
        
        It "Should handle environment detection when no parameters specified" {
            Mock Get-PIMAzureEnvironmentEndpoint { return 'https://management.azure.com/' } -ModuleName EasyPIM -Verifiable
            
            Test-PIMEndpointDiscovery
            
            Should -InvokeVerifiable
        }
    }
    
    Context "Output Formatting" {
        BeforeEach {
            Mock Get-PIMAzureEnvironmentEndpoint {
                if ($EndpointType -eq 'ARM') {
                    return 'https://management.azure.com/'
                } elseif ($EndpointType -eq 'MicrosoftGraph') {
                    return 'https://graph.microsoft.com'
                }
            } -ModuleName EasyPIM
        }
        
        It "Should return properly formatted output" {
            $Result = Test-PIMEndpointDiscovery -EndpointType 'All'
            
            $Result.AzureEnvironment | Should -Not -BeNullOrEmpty
            $Result.ARMEndpoint | Should -Be 'https://management.azure.com/'
            $Result.GraphEndpoint | Should -Be 'https://graph.microsoft.com'
        }
        
        It "Should include test timestamp" {
            $Result = Test-PIMEndpointDiscovery -EndpointType 'All'
            
            $Result.PSObject.Properties.Name | Should -Contain 'Timestamp'
            $Result.Timestamp | Should -BeOfType [DateTime]
        }
    }
    
    Context "Performance" {
        It "Should complete within reasonable time" {
            Mock Get-PIMAzureEnvironmentEndpoint { return 'https://management.azure.com/' } -ModuleName EasyPIM
            
            $StartTime = Get-Date
            Test-PIMEndpointDiscovery -EndpointType 'All'
            $EndTime = Get-Date
            
            ($EndTime - $StartTime).TotalSeconds | Should -BeLessThan 10
        }
        
        It "Should complete connectivity tests within reasonable time" {
            Mock Get-PIMAzureEnvironmentEndpoint { return 'https://management.azure.com/' } -ModuleName EasyPIM
            Mock Test-NetConnection { return @{ TcpTestSucceeded = $true } } -ModuleName EasyPIM
            
            $StartTime = Get-Date
            Test-PIMEndpointDiscovery -EndpointType 'All' -TestConnection
            $EndTime = Get-Date
            
            ($EndTime - $StartTime).TotalSeconds | Should -BeLessThan 30
        }
    }
}

Describe "Test-PIMEndpointDiscovery Real Environment Tests" -Tag "Integration" {
    # These tests require actual Azure connectivity and are tagged as Integration tests
    
    Context "Real Azure Cloud Environments" {
        It "Should successfully test default endpoints" -Skip:(-not (Get-Command Get-AzContext -ErrorAction SilentlyContinue)) {
            $Result = Test-PIMEndpointDiscovery
            
            $Result | Should -Not -BeNullOrEmpty
        }
        
        It "Should successfully test ARM endpoints specifically" -Skip:(-not (Get-Command Get-AzContext -ErrorAction SilentlyContinue)) {
            $Result = Test-PIMEndpointDiscovery -EndpointType 'ARM'
            
            $Result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Real Connectivity Testing" {
        It "Should successfully test connectivity when available" -Skip:(-not (Test-NetConnection google.com -Port 80 -InformationLevel Quiet)) {
            $Result = Test-PIMEndpointDiscovery -EndpointType 'All' -TestConnection
            
            $Result.ConnectionTestResults | Should -Not -BeNullOrEmpty
        }
    }
}
