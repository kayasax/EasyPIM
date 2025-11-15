<#
.SYNOPSIS
    Unit test for Invoke-ARM internal helper.
.DESCRIPTION
    Tests Azure Resource Manager API wrapper with multi-method authentication 
    (environment variables, Azure PowerShell), error handling, and HTTP method support. 
    This is critical infrastructure that all Azure PIM operations depend on.
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
    Describe "Invoke-ARM" -Tag 'Unit', 'InternalFunction', 'CriticalInfrastructure' {
        
        BeforeAll {
            Mock Invoke-RestMethod { return @{} }
            Mock Get-AzContext { return $null }
        }
        
        AfterEach {
            # Clean up environment variables after each test
            Remove-Item env:AZURE_ACCESS_TOKEN -ErrorAction SilentlyContinue
            Remove-Item env:ARM_ACCESS_TOKEN -ErrorAction SilentlyContinue
        }
        
        Context "When making basic GET requests" {
            
            It "Should call ARM API with correct URI and bearer token" {
                # Arrange
                $env:AZURE_ACCESS_TOKEN = "mock-token-123"
                Mock Invoke-RestMethod { return @{ value = @() } }
                
                # Act
                $result = Invoke-ARM -restURI "https://management.azure.com/test" -method "GET"
                
                # Assert
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Uri -eq "https://management.azure.com/test" -and
                    $Headers['Authorization'] -eq "Bearer mock-token-123"
                }
            }
            
            It "Should include Content-Type header" {
                # Arrange
                $env:AZURE_ACCESS_TOKEN = "mock-token"
                
                # Act
                $result = Invoke-ARM -restURI "https://management.azure.com/test" -method "GET"
                
                # Assert
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Headers['Content-Type'] -eq 'application/json'
                }
            }
            
            It "Should return response object directly" {
                # Arrange
                $env:AZURE_ACCESS_TOKEN = "mock-token"
                Mock Invoke-RestMethod {
                    return @{ id = "test-role"; properties = @{ roleName = "Contributor" } }
                }
                
                # Act
                $result = Invoke-ARM -restURI "https://management.azure.com/test" -method "GET"
                
                # Assert
                $result.properties.roleName | Should -Be "Contributor"
            }
        }
        
        Context "When authenticating with environment variables" {
            
            It "Should use AZURE_ACCESS_TOKEN when available" {
                # Arrange
                $env:AZURE_ACCESS_TOKEN = "azure-token"
                
                # Act
                $result = Invoke-ARM -restURI "https://management.azure.com/test" -method "GET"
                
                # Assert
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Headers['Authorization'] -eq "Bearer azure-token"
                }
            }
            
            It "Should use ARM_ACCESS_TOKEN as fallback" {
                # Arrange
                $env:ARM_ACCESS_TOKEN = "arm-token"
                
                # Act
                $result = Invoke-ARM -restURI "https://management.azure.com/test" -method "GET"
                
                # Assert
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Headers['Authorization'] -eq "Bearer arm-token"
                }
            }
            
            It "Should prioritize AZURE_ACCESS_TOKEN over ARM_ACCESS_TOKEN" {
                # Arrange
                $env:AZURE_ACCESS_TOKEN = "priority-token"
                $env:ARM_ACCESS_TOKEN = "fallback-token"
                
                # Act
                $result = Invoke-ARM -restURI "https://management.azure.com/test" -method "GET"
                
                # Assert
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Headers['Authorization'] -eq "Bearer priority-token"
                }
            }
        }
        
        Context "When authenticating with Azure PowerShell Context" {
            
            It "Should use Get-AzAccessToken when context available" {
                # Arrange
                Mock Get-AzContext { return @{ Account = @{ Id = "test@example.com" } } }
                Mock Get-AzAccessToken { return @{ Token = "posh-token" } }
                Mock Invoke-RestMethod { return @{} }
                
                # Act
                $result = Invoke-ARM -restURI "https://management.azure.com/test" -method "GET"
                
                # Assert
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Headers['Authorization'] -eq "Bearer posh-token"
                }
            }
            
            It "Should skip PowerShell when context is null" {
                # Arrange
                Mock Get-AzContext { return $null }
                
                # Act & Assert
                { Invoke-ARM -restURI "https://management.azure.com/test" -method "GET" } | Should -Throw "*Failed to acquire ARM access token*"
            }
        }
        
        Context "When using different HTTP methods" {
            
            It "Should support POST with body" {
                # Arrange
                $env:AZURE_ACCESS_TOKEN = "mock-token"
                $body = '{"properties":{"principalId":"test-id"}}'
                
                # Act
                $result = Invoke-ARM -restURI "https://management.azure.com/test" -method "POST" -body $body
                
                # Assert
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Method -eq "POST" -and $Body -eq $body
                }
            }
            
            It "Should support DELETE method" {
                # Arrange
                $env:AZURE_ACCESS_TOKEN = "mock-token"
                
                # Act
                $result = Invoke-ARM -restURI "https://management.azure.com/test" -method "DELETE"
                
                # Assert
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Method -eq "DELETE"
                }
            }
            
            It "Should not include body when empty string" {
                # Arrange
                $env:AZURE_ACCESS_TOKEN = "mock-token"
                
                # Act
                $result = Invoke-ARM -restURI "https://management.azure.com/test" -method "GET" -body ""
                
                # Assert
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    -not $PSBoundParameters.ContainsKey('Body')
                }
            }
        }
        
        Context "When handling errors" {
            
            It "Should throw error when API call fails" {
                # Arrange
                $env:AZURE_ACCESS_TOKEN = "mock-token"
                Mock Invoke-RestMethod { throw "404 Not Found" }
                
                # Act & Assert
                { Invoke-ARM -restURI "https://management.azure.com/invalid" -method "GET" } | Should -Throw "*ARM API call failed*"
            }
            
            It "Should throw when no authentication available" {
                # Arrange
                Mock Get-AzContext { return $null }
                
                # Act & Assert
                { Invoke-ARM -restURI "https://management.azure.com/test" -method "GET" } | Should -Throw "*Failed to acquire ARM access token*"
            }
            
            It "Should include OIDC guidance in error" {
                # Arrange
                Mock Get-AzContext { return $null }
                
                # Act & Assert
                { Invoke-ARM -restURI "https://management.azure.com/test" -method "GET" } | Should -Throw "*azure/login@v2*"
            }
            
            It "Should throw for 403 Forbidden" {
                # Arrange
                $env:AZURE_ACCESS_TOKEN = "mock-token"
                Mock Invoke-RestMethod { throw "403 Forbidden" }
                
                # Act & Assert
                { Invoke-ARM -restURI "https://management.azure.com/test" -method "GET" } | Should -Throw "*403*"
            }
        }
        
        Context "When handling edge cases" {
            
            It "Should validate restURI not empty" {
                # Arrange
                $env:AZURE_ACCESS_TOKEN = "mock-token"
                
                # Act & Assert
                { Invoke-ARM -restURI "" -method "GET" } | Should -Throw
            }
            
            It "Should handle URIs with query parameters" {
                # Arrange
                $env:AZURE_ACCESS_TOKEN = "mock-token"
                $uriWithQuery = "https://management.azure.com/test?api-version=2022-04-01"
                Mock Invoke-RestMethod { return @{} }
                
                # Act
                $result = Invoke-ARM -restURI $uriWithQuery -method "GET"
                
                # Assert
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Uri -eq $uriWithQuery
                }
            }
        }
    }
}
