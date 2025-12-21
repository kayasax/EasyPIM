<#
.SYNOPSIS
    Unit test for Get-Entrarole internal helper.
.DESCRIPTION
    Tests the Get-Entrarole function which retrieves all Entra role display names
    from the roleManagement/directory/roleDefinitions endpoint. Tests cover
    successful role retrieval, empty results, API errors, and mock invoke-graph.
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

Describe "Get-Entrarole" -Tag 'Unit', 'InternalHelper' {
    
    BeforeAll {
        # Import module
        $modulePath = Join-Path $PSScriptRoot "..\..\..\EasyPIM\EasyPIM.psd1"
        Import-Module $modulePath -Force -ErrorAction Stop
        
        # Mock script-level tenantID
        InModuleScope EasyPIM {
            $script:tenantID = "test-tenant-123"
        }
    }
    
    Context "When retrieving Entra roles successfully" {
        
        It "Should return list of role display names" {
            InModuleScope EasyPIM {
                # Arrange
                $mockResponse = @{
                    value = @(
                        @{ displayname = "Global Administrator" }
                        @{ displayname = "Security Reader" }
                        @{ displayname = "User Administrator" }
                    )
                }
                Mock invoke-graph { return $mockResponse }
                
                # Act
                $result = Get-Entrarole -tenantID "test-tenant"
                
                # Assert
                $result | Should -HaveCount 3
                $result | Should -Contain "Global Administrator"
                $result | Should -Contain "Security Reader"
                $result | Should -Contain "User Administrator"
            }
        }
        
        It "Should call invoke-graph with correct endpoint" {
            InModuleScope EasyPIM {
                # Arrange
                $mockResponse = @{ value = @() }
                Mock invoke-graph { return $mockResponse }
                
                # Act
                Get-Entrarole -tenantID "test-tenant"
                
                # Assert
                Should -Invoke invoke-graph -Times 1 -ParameterFilter {
                    $Endpoint -like "roleManagement/directory/roleDefinitions*" -and
                    $Endpoint -like "*`$select=displayname*"
                }
            }
        }
        
        It "Should use script-level tenantID when parameter provided" {
            InModuleScope EasyPIM {
                # Arrange
                $script:tenantID = "script-tenant-456"
                $mockResponse = @{ value = @() }
                Mock invoke-graph { return $mockResponse }
                
                # Act
                Get-Entrarole -tenantID "ignored-tenant"
                
                # Assert
                Should -Invoke invoke-graph -Times 1
                # Function always uses script:tenantID regardless of parameter
            }
        }
    }
    
    Context "When handling empty or minimal results" {
        
        It "Should return empty array when no roles found" {
            InModuleScope EasyPIM {
                # Arrange
                $mockResponse = @{ value = @() }
                Mock invoke-graph { return $mockResponse }
                
                # Act
                $result = Get-Entrarole
                
                # Assert
                $result | Should -BeNullOrEmpty
            }
        }
        
        It "Should handle single role response" {
            InModuleScope EasyPIM {
                # Arrange
                $mockResponse = @{
                    value = @(
                        @{ displayname = "Single Role" }
                    )
                }
                Mock invoke-graph { return $mockResponse }
                
                # Act
                $result = Get-Entrarole
                
                # Assert
                $result | Should -HaveCount 1
                $result | Should -Be "Single Role"
            }
        }
    }
    
    Context "When handling API errors" {
        
        It "Should propagate invoke-graph errors" {
            InModuleScope EasyPIM {
                # Arrange
                Mock invoke-graph { throw "API Error: 401 Unauthorized" }
                
                # Act & Assert
                { Get-Entrarole } | Should -Throw "*API Error*"
            }
        }
        
        It "Should handle null response from invoke-graph" {
            InModuleScope EasyPIM {
                # Arrange
                Mock invoke-graph { return $null }
                
                # Act
                $result = Get-Entrarole
                
                # Assert
                # Function doesn't throw on null, it returns empty/null result
                $result | Should -BeNullOrEmpty
            }
        }
    }
    
    Context "When handling role name variations" {
        
        It "Should preserve exact display name casing" {
            InModuleScope EasyPIM {
                # Arrange
                $mockResponse = @{
                    value = @(
                        @{ displayname = "MixedCase Role Name" }
                        @{ displayname = "ALL CAPS ROLE" }
                        @{ displayname = "lowercase role" }
                    )
                }
                Mock invoke-graph { return $mockResponse }
                
                # Act
                $result = Get-Entrarole
                
                # Assert
                $result | Should -Contain "MixedCase Role Name"
                $result | Should -Contain "ALL CAPS ROLE"
                $result | Should -Contain "lowercase role"
            }
        }
        
        It "Should handle roles with special characters" {
            InModuleScope EasyPIM {
                # Arrange
                $mockResponse = @{
                    value = @(
                        @{ displayname = "Role-With-Dashes" }
                        @{ displayname = "Role (with parens)" }
                        @{ displayname = "Role & Symbols" }
                    )
                }
                Mock invoke-graph { return $mockResponse }
                
                # Act
                $result = Get-Entrarole
                
                # Assert
                $result | Should -HaveCount 3
                $result | Should -Contain "Role-With-Dashes"
            }
        }
    }
}
