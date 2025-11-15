<#
.SYNOPSIS
    Unit test for Get-RoleMappings internal helper.
.DESCRIPTION
    Tests the Get-RoleMappings function which provides Azure RBAC role name ↔ ID mappings
    for a subscription. Tests cover mapping retrieval, caching, bidirectional lookups,
    and Get-AzRoleDefinition mocking.
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

Describe "Get-RoleMappings" -Tag 'Unit', 'InternalHelper' {
    
    BeforeAll {
        # Clear role cache before tests
        InModuleScope EasyPIM {
            $script:roleCache = @{}
        }
    }
    
    BeforeEach {
        # Reset cache before each test
        InModuleScope EasyPIM {
            $script:roleCache = @{}
        }
    }
    
    Context "When retrieving role mappings successfully" {
        
        It "Should return hashtable with NameToId, IdToName, and FullPathToName maps" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "test-sub-123"
                $mockRoles = @(
                    [PSCustomObject]@{ Name = "Owner"; Id = "owner-guid" }
                    [PSCustomObject]@{ Name = "Contributor"; Id = "contrib-guid" }
                )
                Mock Get-AzRoleDefinition { return $mockRoles }
                
                # Act
                $result = Get-RoleMappings -SubscriptionId $subId
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.NameToId | Should -Not -BeNullOrEmpty
                $result.IdToName | Should -Not -BeNullOrEmpty
                $result.FullPathToName | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should map role name to ID correctly" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "test-sub-456"
                $mockRoles = @(
                    [PSCustomObject]@{ Name = "Reader"; Id = "reader-id-789" }
                )
                Mock Get-AzRoleDefinition { return $mockRoles }
                
                # Act
                $result = Get-RoleMappings -SubscriptionId $subId
                
                # Assert
                $result.NameToId["Reader"] | Should -Be "reader-id-789"
            }
        }
        
        It "Should map role ID to name correctly" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "test-sub-789"
                $mockRoles = @(
                    [PSCustomObject]@{ Name = "Virtual Machine Contributor"; Id = "vm-contrib-id" }
                )
                Mock Get-AzRoleDefinition { return $mockRoles }
                
                # Act
                $result = Get-RoleMappings -SubscriptionId $subId
                
                # Assert
                $result.IdToName["vm-contrib-id"] | Should -Be "Virtual Machine Contributor"
            }
        }
        
        It "Should map full resource path to name correctly" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "test-sub-abc"
                $mockRoles = @(
                    [PSCustomObject]@{ Name = "Storage Blob Data Owner"; Id = "blob-owner-id" }
                )
                Mock Get-AzRoleDefinition { return $mockRoles }
                
                # Act
                $result = Get-RoleMappings -SubscriptionId $subId
                
                # Assert
                $expectedPath = "/subscriptions/test-sub-abc/providers/Microsoft.Authorization/roleDefinitions/blob-owner-id"
                $result.FullPathToName[$expectedPath] | Should -Be "Storage Blob Data Owner"
            }
        }
        
        It "Should handle multiple roles correctly" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "multi-sub"
                $mockRoles = @(
                    [PSCustomObject]@{ Name = "Owner"; Id = "owner-id" }
                    [PSCustomObject]@{ Name = "Contributor"; Id = "contrib-id" }
                    [PSCustomObject]@{ Name = "Reader"; Id = "reader-id" }
                )
                Mock Get-AzRoleDefinition { return $mockRoles }
                
                # Act
                $result = Get-RoleMappings -SubscriptionId $subId
                
                # Assert
                $result.NameToId.Count | Should -Be 3
                $result.IdToName.Count | Should -Be 3
                $result.FullPathToName.Count | Should -Be 3
            }
        }
    }
    
    Context "When caching role mappings" {
        
        It "Should cache mappings after first call" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "cache-test-sub"
                $mockRoles = @(
                    [PSCustomObject]@{ Name = "Test Role"; Id = "test-id" }
                )
                Mock Get-AzRoleDefinition { return $mockRoles }
                
                # Act
                $result1 = Get-RoleMappings -SubscriptionId $subId
                $result2 = Get-RoleMappings -SubscriptionId $subId
                
                # Assert
                Should -Invoke Get-AzRoleDefinition -Times 1 # Only called once
                $result1.NameToId["Test Role"] | Should -Be $result2.NameToId["Test Role"]
            }
        }
        
        It "Should return cached result on subsequent calls" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "cached-sub"
                $mockRoles = @(
                    [PSCustomObject]@{ Name = "Cached Role"; Id = "cached-id" }
                )
                Mock Get-AzRoleDefinition { return $mockRoles }
                
                # Act
                Get-RoleMappings -SubscriptionId $subId # First call - caches
                $result = Get-RoleMappings -SubscriptionId $subId # Second call - from cache
                
                # Assert
                $result.NameToId["Cached Role"] | Should -Be "cached-id"
                Should -Invoke Get-AzRoleDefinition -Times 1
            }
        }
        
        It "Should maintain separate cache per subscription" {
            InModuleScope EasyPIM {
                # Arrange
                $sub1 = "sub-one"
                $sub2 = "sub-two"
                $mockRoles1 = @(
                    [PSCustomObject]@{ Name = "Role 1"; Id = "id-1" }
                )
                $mockRoles2 = @(
                    [PSCustomObject]@{ Name = "Role 2"; Id = "id-2" }
                )
                Mock Get-AzRoleDefinition { 
                    if ($Scope -like "*sub-one*") { return $mockRoles1 }
                    else { return $mockRoles2 }
                }
                
                # Act
                $result1 = Get-RoleMappings -SubscriptionId $sub1
                $result2 = Get-RoleMappings -SubscriptionId $sub2
                
                # Assert
                $result1.NameToId["Role 1"] | Should -Be "id-1"
                $result2.NameToId["Role 2"] | Should -Be "id-2"
                Should -Invoke Get-AzRoleDefinition -Times 2
            }
        }
    }
    
    Context "When handling edge cases" {
        
        It "Should handle empty role list" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "empty-sub"
                Mock Get-AzRoleDefinition { return @() }
                
                # Act
                $result = Get-RoleMappings -SubscriptionId $subId
                
                # Assert
                $result.NameToId.Count | Should -Be 0
                $result.IdToName.Count | Should -Be 0
                $result.FullPathToName.Count | Should -Be 0
            }
        }
        
        It "Should handle single role" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "single-sub"
                $mockRoles = @(
                    [PSCustomObject]@{ Name = "Only Role"; Id = "only-id" }
                )
                Mock Get-AzRoleDefinition { return $mockRoles }
                
                # Act
                $result = Get-RoleMappings -SubscriptionId $subId
                
                # Assert
                $result.NameToId.Count | Should -Be 1
                $result.NameToId["Only Role"] | Should -Be "only-id"
            }
        }
        
        It "Should handle roles with special characters in names" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "special-sub"
                $mockRoles = @(
                    [PSCustomObject]@{ Name = "Role (Preview)"; Id = "preview-id" }
                    [PSCustomObject]@{ Name = "Role/Slash"; Id = "slash-id" }
                )
                Mock Get-AzRoleDefinition { return $mockRoles }
                
                # Act
                $result = Get-RoleMappings -SubscriptionId $subId
                
                # Assert
                $result.NameToId["Role (Preview)"] | Should -Be "preview-id"
                $result.NameToId["Role/Slash"] | Should -Be "slash-id"
            }
        }
    }
    
    Context "When handling errors" {
        
        It "Should propagate Get-AzRoleDefinition errors" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "error-sub"
                Mock Get-AzRoleDefinition { throw "Subscription not found" }
                
                # Act & Assert
                { Get-RoleMappings -SubscriptionId $subId } | Should -Throw "*Subscription not found*"
            }
        }
        
        It "Should call Get-AzRoleDefinition with correct scope parameter" {
            InModuleScope EasyPIM {
                # Arrange
                $subId = "scope-test-sub"
                $mockRoles = @(
                    [PSCustomObject]@{ Name = "Test"; Id = "test" }
                )
                Mock Get-AzRoleDefinition { return $mockRoles }
                
                # Act
                Get-RoleMappings -SubscriptionId $subId
                
                # Assert
                Should -Invoke Get-AzRoleDefinition -Times 1 -ParameterFilter {
                    $Scope -eq "/subscriptions/scope-test-sub"
                }
            }
        }
    }
}
