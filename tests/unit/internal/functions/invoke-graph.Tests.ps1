<#
.SYNOPSIS
    Unit test for invoke-graph internal helper.
.DESCRIPTION
    Tests Microsoft Graph API wrapper with pagination, error handling, environment detection,
    and multi-method support (GET/POST/PUT/PATCH/DELETE). This is critical infrastructure
    that all Entra/Graph operations depend on.
.NOTES
    Template Version: 1.1
    Created: November 13, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalFunction, CriticalInfrastructure
#>

BeforeAll {
    Import-Module "$PSScriptRoot/../../../../EasyPIM/EasyPIM.psd1" -Force
}

InModuleScope EasyPIM {
    Describe "invoke-graph" -Tag 'Unit', 'InternalFunction', 'CriticalInfrastructure' {
        
        BeforeAll {
            Mock Invoke-MgGraphRequest {
                return @{ value = @() }
            }
            Mock Get-AzContext { return $null }
        }
        
        Context "When making basic GET requests" {
            
            It "Should call Graph API with correct default endpoint" {
                # Act
                $result = invoke-graph -Endpoint "users"
                
                # Assert
                Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri -eq "https://graph.microsoft.com/v1.0/users" -and $Method -eq "GET"
                }
            }
            
            It "Should use beta version when specified" {
                # Act
                $result = invoke-graph -Endpoint "users" -version "beta"
                
                # Assert
                Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri -eq "https://graph.microsoft.com/beta/users"
                }
            }
            
            It "Should return response object directly" {
                # Arrange
                Mock Invoke-MgGraphRequest {
                    return @{ id = "test-id"; displayName = "Test User" }
                }
                
                # Act
                $result = invoke-graph -Endpoint "users/test-id"
                
                # Assert
                $result.id | Should -Be "test-id"
                $result.displayName | Should -Be "Test User"
            }
        }
        
        Context "When using OData filters" {
            
            It "Should append filter parameter correctly" {
                # Act
                $result = invoke-graph -Endpoint "users" -Filter "userPrincipalName eq 'test@example.com'"
                
                # Assert
                Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri -like "*?`$filter=*"
                }
            }
        }
        
        Context "When handling pagination" {
            
            It "Should follow nextLink and aggregate results" {
                # Arrange
                $page1 = @{
                    value = @(@{ id = "user-1" }, @{ id = "user-2" })
                    '@odata.nextLink' = "https://graph.microsoft.com/v1.0/users?`$skiptoken=page2"
                }
                $page2 = @{
                    value = @(@{ id = "user-3" })
                    '@odata.nextLink' = $null
                }
                Mock Invoke-MgGraphRequest {
                    param($Uri)
                    if ($Uri -like "*skiptoken=page2*") { return $page2 } else { return $page1 }
                }
                
                # Act
                $result = invoke-graph -Endpoint "users"
                
                # Assert
                $result.value | Should -HaveCount 3
                $result.value[2].id | Should -Be "user-3"
            }
            
            It "Should skip pagination when NoPagination switch is used" {
                # Arrange
                Mock Invoke-MgGraphRequest {
                    return @{
                        value = @(@{ id = "user-1" })
                        '@odata.nextLink' = "https://graph.microsoft.com/v1.0/users?skiptoken=page2"
                    }
                }
                
                # Act
                $result = invoke-graph -Endpoint "users" -NoPagination
                
                # Assert
                Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly
                $result.'@odata.nextLink' | Should -Not -BeNullOrEmpty
            }
        }
        
        Context "When using different HTTP methods" {
            
            It "Should support POST method with body" {
                # Arrange
                $body = '{"displayName":"New Group"}'
                Mock Invoke-MgGraphRequest { return @{ id = "new-id" } }
                
                # Act
                $result = invoke-graph -Endpoint "groups" -Method "POST" -body $body
                
                # Assert
                Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
                    $Method -eq "POST" -and $Body -eq $body
                }
            }
            
            It "Should not include body parameter for GET when empty" {
                # Act
                $result = invoke-graph -Endpoint "users" -Method "GET"
                
                # Assert
                Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
                    -not $PSBoundParameters.ContainsKey('Body')
                }
            }
        }
        
        Context "When detecting Azure environment" {
            
            It "Should use US Government endpoint" {
                # Arrange
                Mock Get-AzContext { return @{ Environment = @{ Name = 'AzureUSGovernment' } } }
                Mock Invoke-MgGraphRequest { return @{ value = @() } }
                
                # Act
                $result = invoke-graph -Endpoint "users"
                
                # Assert
                Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri -like "https://graph.microsoft.us/*"
                }
            }
            
            It "Should use China Cloud endpoint" {
                # Arrange
                Mock Get-AzContext { return @{ Environment = @{ Name = 'AzureChinaCloud' } } }
                Mock Invoke-MgGraphRequest { return @{ value = @() } }
                
                # Act
                $result = invoke-graph -Endpoint "users"
                
                # Assert
                Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri -like "https://microsoftgraph.chinacloudapi.cn/*"
                }
            }
            
            It "Should fallback to default when Get-AzContext fails" {
                # Arrange
                Mock Get-AzContext { throw "No context" }
                Mock Invoke-MgGraphRequest { return @{ value = @() } }
                
                # Act
                $result = invoke-graph -Endpoint "users"
                
                # Assert
                Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri -like "https://graph.microsoft.com/*"
                }
            }
        }
        
        Context "When handling errors" {
            
            It "Should throw error when API call fails" {
                # Arrange
                Mock Invoke-MgGraphRequest { throw "404 Not Found" }
                
                # Act & Assert
                { invoke-graph -Endpoint "users/invalid-id" } | Should -Throw
            }
            
            It "Should throw for 403 Forbidden" {
                # Arrange
                Mock Invoke-MgGraphRequest { throw "403 Forbidden" }
                
                # Act & Assert
                { invoke-graph -Endpoint "users" } | Should -Throw "*403*"
            }
        }
    }
}
