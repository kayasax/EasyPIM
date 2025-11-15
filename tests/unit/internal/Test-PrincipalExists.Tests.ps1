<#
.SYNOPSIS
    Unit test for Test-PrincipalExists internal helper.
.DESCRIPTION
    Tests principal existence validation via Microsoft Graph API.
    Validates success paths, not found scenarios, and error handling.
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

# Module imported by test runner (pester-modern.ps1)

Describe "Test-PrincipalExists" {
    
    Context "When principal exists in Azure AD" {
        
        It "Should return true for valid principal ID" {
            InModuleScope EasyPIM {
                # Arrange
                $principalId = "12345678-1234-1234-1234-123456789012"
                Mock invoke-graph {
                    return @{
                        id = $principalId
                        displayName = "Test User"
                        userPrincipalName = "testuser@contoso.com"
                    }
                }
                
                # Act
                $result = Test-PrincipalExists -PrincipalId $principalId
                
                # Assert
                $result | Should -Be $true
                Should -Invoke invoke-graph -Times 1 -Exactly -ParameterFilter {
                    $Endpoint -eq "directoryObjects/$principalId"
                }
            }
        }
        
        It "Should return true for service principal ID" {
            InModuleScope EasyPIM {
                # Arrange
                $principalId = "87654321-4321-4321-4321-210987654321"
                Mock invoke-graph {
                    return @{
                        id = $principalId
                        displayName = "Service Principal App"
                        appId = "abcd1234-5678-90ef-ghij-klmnopqrstuv"
                    }
                }
                
                # Act
                $result = Test-PrincipalExists -PrincipalId $principalId
                
                # Assert
                $result | Should -Be $true
            }
        }
        
        It "Should return true for group ID" {
            InModuleScope EasyPIM {
                # Arrange
                $principalId = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
                Mock invoke-graph {
                    return @{
                        id = $principalId
                        displayName = "Test Group"
                        mailNickname = "testgroup"
                    }
                }
                
                # Act
                $result = Test-PrincipalExists -PrincipalId $principalId
                
                # Assert
                $result | Should -Be $true
            }
        }
    }
    
    Context "When principal does not exist" {
        
        It "Should return false when principal is not found (404)" {
            InModuleScope EasyPIM {
                # Arrange
                $principalId = "99999999-9999-9999-9999-999999999999"
                Mock invoke-graph {
                    throw [System.Net.WebException]::new("Resource not found")
                }
                
                # Act
                $result = Test-PrincipalExists -PrincipalId $principalId
                
                # Assert
                $result | Should -Be $false
            }
        }
        
        It "Should return false when Graph API returns error" {
            InModuleScope EasyPIM {
                # Arrange
                $principalId = "invalid-guid-format"
                Mock invoke-graph {
                    throw "Invalid GUID format"
                }
                
                # Act
                $result = Test-PrincipalExists -PrincipalId $principalId
                
                # Assert
                $result | Should -Be $false
            }
        }
        
        It "Should return false when access is denied" {
            InModuleScope EasyPIM {
                # Arrange
                $principalId = "00000000-0000-0000-0000-000000000000"
                Mock invoke-graph {
                    throw [System.UnauthorizedAccessException]::new("Access denied")
                }
                
                # Act
                $result = Test-PrincipalExists -PrincipalId $principalId
                
                # Assert
                $result | Should -Be $false
            }
        }
    }
    
    Context "When handling Graph API errors" {
        
        It "Should return false on network timeout" {
            InModuleScope EasyPIM {
                # Arrange
                $principalId = "11111111-2222-3333-4444-555555555555"
                Mock invoke-graph {
                    throw [System.TimeoutException]::new("Request timed out")
                }
                
                # Act
                $result = Test-PrincipalExists -PrincipalId $principalId
                
                # Assert
                $result | Should -Be $false
            }
        }
        
        It "Should return false on Graph API throttling" {
            InModuleScope EasyPIM {
                # Arrange
                $principalId = "aaaabbbb-cccc-dddd-eeee-ffffffff0000"
                Mock invoke-graph {
                    throw "Too many requests (429)"
                }
                
                # Act
                $result = Test-PrincipalExists -PrincipalId $principalId
                
                # Assert
                $result | Should -Be $false
            }
        }
        
        It "Should return false on generic Graph API error" {
            InModuleScope EasyPIM {
                # Arrange
                $principalId = "deadbeef-dead-beef-dead-beefdeadbeef"
                Mock invoke-graph {
                    throw "Internal server error"
                }
                
                # Act
                $result = Test-PrincipalExists -PrincipalId $principalId
                
                # Assert
                $result | Should -Be $false
            }
        }
    }
    
    Context "When validating function behavior" {
        
        It "Should call invoke-graph with correct endpoint format" {
            InModuleScope EasyPIM {
                # Arrange
                $principalId = "testid-1234-5678-90ab-cdef12345678"
                Mock invoke-graph {
                    return @{ id = $principalId }
                }
                
                # Act
                $result = Test-PrincipalExists -PrincipalId $principalId
                
                # Assert
                Should -Invoke invoke-graph -Times 1 -Exactly -ParameterFilter {
                    $Endpoint -match "^directoryObjects/[a-zA-Z0-9\-]+$"
                }
            }
        }
        
        It "Should use ErrorAction Stop for invoke-graph call" {
            InModuleScope EasyPIM {
                # Arrange
                $principalId = "12345678-abcd-ef12-3456-7890abcdef12"
                Mock invoke-graph {
                    return @{ id = $principalId }
                }
                
                # Act
                $result = Test-PrincipalExists -PrincipalId $principalId
                
                # Assert
                Should -Invoke invoke-graph -Times 1 -Exactly -ParameterFilter {
                    $ErrorAction -eq 'Stop'
                }
            }
        }
        
        It "Should return boolean type only" {
            InModuleScope EasyPIM {
                # Arrange
                $principalId = "bool-test-1234-5678-90ab-cdef12345678"
                Mock invoke-graph {
                    return @{ id = $principalId }
                }
                
                # Act
                $result = Test-PrincipalExists -PrincipalId $principalId
                
                # Assert
                $result.GetType().Name | Should -Be 'Boolean'
            }
        }
    }
}
