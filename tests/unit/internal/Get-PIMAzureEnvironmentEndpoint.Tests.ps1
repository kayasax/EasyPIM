<#
.SYNOPSIS
    Unit test for Get-PIMAzureEnvironmentEndpoint internal helper.
.DESCRIPTION
    Tests Azure environment endpoint URL resolution for different cloud environments.
    Validates ARM and Microsoft Graph endpoints across all Azure environments.
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

# Module imported by test runner (pester-modern.ps1)

Describe "Get-PIMAzureEnvironmentEndpoint" {
    
    BeforeAll {
        InModuleScope EasyPIM {
            # Mock Get-AzContext to control environment detection
            Mock Get-AzContext {
                return @{
                    Environment = @{
                        Name = 'AzureCloud'
                    }
                }
            }
        }
    }
    
    Context "When requesting ARM endpoints in different Azure environments" {
        
        It "Should return public Azure ARM endpoint for AzureCloud" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext {
                    return @{
                        Environment = @{
                            Name = 'AzureCloud'
                        }
                    }
                }
                
                # Act
                $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
                
                # Assert
                $result | Should -Be 'https://management.azure.com/'
            }
        }
        
        It "Should return US Government ARM endpoint for AzureUSGovernment" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext {
                    return @{
                        Environment = @{
                            Name = 'AzureUSGovernment'
                        }
                    }
                }
                
                # Act
                $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
                
                # Assert
                $result | Should -Be 'https://management.usgovcloudapi.net/'
            }
        }
        
        It "Should return China Cloud ARM endpoint for AzureChinaCloud" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext {
                    return @{
                        Environment = @{
                            Name = 'AzureChinaCloud'
                        }
                    }
                }
                
                # Act
                $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
                
                # Assert
                $result | Should -Be 'https://management.chinacloudapi.cn/'
            }
        }
        
        It "Should return German Cloud ARM endpoint for AzureGermanCloud" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext {
                    return @{
                        Environment = @{
                            Name = 'AzureGermanCloud'
                        }
                    }
                }
                
                # Act
                $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
                
                # Assert
                $result | Should -Be 'https://management.microsoftazure.de/'
            }
        }
    }
    
    Context "When requesting Microsoft Graph endpoints in different Azure environments" {
        
        It "Should return public Azure Graph endpoint for AzureCloud" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext {
                    return @{
                        Environment = @{
                            Name = 'AzureCloud'
                        }
                    }
                }
                
                # Act
                $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
                
                # Assert
                $result | Should -Be 'https://graph.microsoft.com'
            }
        }
        
        It "Should return US Government Graph endpoint for AzureUSGovernment" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext {
                    return @{
                        Environment = @{
                            Name = 'AzureUSGovernment'
                        }
                    }
                }
                
                # Act
                $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
                
                # Assert
                $result | Should -Be 'https://graph.microsoft.us'
            }
        }
        
        It "Should return China Cloud Graph endpoint for AzureChinaCloud" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext {
                    return @{
                        Environment = @{
                            Name = 'AzureChinaCloud'
                        }
                    }
                }
                
                # Act
                $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
                
                # Assert
                $result | Should -Be 'https://microsoftgraph.chinacloudapi.cn'
            }
        }
        
        It "Should return German Cloud Graph endpoint for AzureGermanCloud" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext {
                    return @{
                        Environment = @{
                            Name = 'AzureGermanCloud'
                        }
                    }
                }
                
                # Act
                $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
                
                # Assert
                $result | Should -Be 'https://graph.microsoft.de'
            }
        }
    }
    
    Context "When Get-AzContext fails or returns null" {
        
        It "Should default to public Azure ARM endpoint when Get-AzContext fails" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext {
                    throw "Not connected"
                }
                
                # Act
                $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
                
                # Assert
                $result | Should -Be 'https://management.azure.com/'
            }
        }
        
        It "Should default to public Azure Graph endpoint when Get-AzContext fails" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext {
                    throw "Not connected"
                }
                
                # Act
                $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
                
                # Assert
                $result | Should -Be 'https://graph.microsoft.com'
            }
        }
        
        It "Should default to public Azure ARM endpoint when Get-AzContext returns null" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext {
                    return $null
                }
                
                # Act
                $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM'
                
                # Assert
                $result | Should -Be 'https://management.azure.com/'
            }
        }
        
        It "Should default to public Azure Graph endpoint when Get-AzContext returns null" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext {
                    return $null
                }
                
                # Act
                $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'MicrosoftGraph'
                
                # Assert
                $result | Should -Be 'https://graph.microsoft.com'
            }
        }
    }
    
    Context "When using NoCache parameter" {
        
        It "Should accept NoCache switch without error (compatibility)" {
            InModuleScope EasyPIM {
                # Arrange
                Mock Get-AzContext {
                    return @{
                        Environment = @{
                            Name = 'AzureCloud'
                        }
                    }
                }
                
                # Act
                $result = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM' -NoCache
                
                # Assert
                $result | Should -Be 'https://management.azure.com/'
            }
        }
    }
}
