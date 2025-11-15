<#
.SYNOPSIS
    Unit test for Resolve-EasyPIMDirectoryScope internal helper.
.DESCRIPTION
    Tests directory scope resolution logic for tenant root and administrative units.
    Validates GUID resolution, display name lookup, scope normalization, and error handling.
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

# Module imported by test runner (pester-modern.ps1)

Describe "Resolve-EasyPIMDirectoryScope" {
    
    Context "When resolving default tenant root scope" {
        
        It "Should return default scope '/' when Scope is null" {
            InModuleScope EasyPIM {
                # Arrange & Act
                $result = Resolve-EasyPIMDirectoryScope -Scope $null
                
                # Assert
                $result | Should -Be '/'
            }
        }
        
        It "Should return default scope '/' when Scope is empty string" {
            InModuleScope EasyPIM {
                # Arrange & Act
                $result = Resolve-EasyPIMDirectoryScope -Scope ""
                
                # Assert
                $result | Should -Be '/'
            }
        }
        
        It "Should return default scope '/' when Scope is whitespace" {
            InModuleScope EasyPIM {
                # Arrange & Act
                $result = Resolve-EasyPIMDirectoryScope -Scope "   "
                
                # Assert
                $result | Should -Be '/'
            }
        }
        
        It "Should use custom DefaultScope when provided" {
            InModuleScope EasyPIM {
                # Arrange & Act
                $result = Resolve-EasyPIMDirectoryScope -Scope "" -DefaultScope "/customDefault"
                
                # Assert
                $result | Should -Be '/customDefault'
            }
        }
    }
    
    Context "When resolving root/tenant scope aliases" {
        
        It "Should return '/' for forward slash input" {
            InModuleScope EasyPIM {
                # Arrange & Act
                $result = Resolve-EasyPIMDirectoryScope -Scope "/"
                
                # Assert
                $result | Should -Be '/'
            }
        }
        
        It "Should return '/' for backslash input" {
            InModuleScope EasyPIM {
                # Arrange & Act
                # Note: Single backslash treated as escape char in PowerShell strings
                # Function checks for '\\' (double backslash) which is a single backslash in string literal
                $result = Resolve-EasyPIMDirectoryScope -Scope '\\'
                
                # Assert
                $result | Should -Be '/'
            }
        }
        
        It "Should return '/' for 'tenant' keyword" {
            InModuleScope EasyPIM {
                # Arrange & Act
                $result = Resolve-EasyPIMDirectoryScope -Scope "tenant"
                
                # Assert
                $result | Should -Be '/'
            }
        }
        
        It "Should return '/' for 'directory' keyword" {
            InModuleScope EasyPIM {
                # Arrange & Act
                $result = Resolve-EasyPIMDirectoryScope -Scope "directory"
                
                # Assert
                $result | Should -Be '/'
            }
        }
        
        It "Should return '/' for 'root' keyword" {
            InModuleScope EasyPIM {
                # Arrange & Act
                $result = Resolve-EasyPIMDirectoryScope -Scope "root"
                
                # Assert
                $result | Should -Be '/'
            }
        }
        
        It "Should handle root keywords with whitespace" {
            InModuleScope EasyPIM {
                # Arrange & Act
                $result = Resolve-EasyPIMDirectoryScope -Scope "  tenant  "
                
                # Assert
                $result | Should -Be '/'
            }
        }
    }
    
    Context "When resolving full scope paths" {
        
        It "Should return scope as-is when it starts with forward slash" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "/administrativeUnits/12345678-1234-1234-1234-123456789012"
                
                # Act
                $result = Resolve-EasyPIMDirectoryScope -Scope $scope
                
                # Assert
                $result | Should -Be $scope
            }
        }
        
        It "Should preserve any valid slash-prefixed path" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "/custom/path/structure"
                
                # Act
                $result = Resolve-EasyPIMDirectoryScope -Scope $scope
                
                # Assert
                $result | Should -Be $scope
            }
        }
    }
    
    Context "When resolving administrative unit GUID" {
        
        It "Should convert bare GUID to /administrativeUnits/GUID format" {
            InModuleScope EasyPIM {
                # Arrange
                $guid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
                
                # Act
                $result = Resolve-EasyPIMDirectoryScope -Scope $guid
                
                # Assert
                $result | Should -Be "/administrativeUnits/$guid"
            }
        }
        
        It "Should recognize GUID with mixed case" {
            InModuleScope EasyPIM {
                # Arrange
                $guid = "AaBbCcDd-EeFf-1122-3344-556677889900"
                
                # Act
                $result = Resolve-EasyPIMDirectoryScope -Scope $guid
                
                # Assert
                $result | Should -Be "/administrativeUnits/$guid"
            }
        }
        
        It "Should handle GUID with uppercase characters" {
            InModuleScope EasyPIM {
                # Arrange
                $guid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                
                # Act
                $result = Resolve-EasyPIMDirectoryScope -Scope $guid
                
                # Assert
                $result | Should -Be "/administrativeUnits/$guid"
            }
        }
    }
    
    Context "When resolving administrativeUnits prefix paths" {
        
        It "Should add leading slash to administrativeUnits/GUID without slash" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "administrativeUnits/12345678-1234-1234-1234-123456789012"
                
                # Act
                $result = Resolve-EasyPIMDirectoryScope -Scope $scope
                
                # Assert
                $result | Should -Be "/$scope"
            }
        }
        
        It "Should preserve /administrativeUnits/GUID path with leading slash" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "/administrativeUnits/87654321-4321-4321-4321-210987654321"
                
                # Act
                $result = Resolve-EasyPIMDirectoryScope -Scope $scope
                
                # Assert
                $result | Should -Be $scope
            }
        }
    }
    
    Context "When resolving administrative unit display name" {
        
        It "Should resolve display name to /administrativeUnits/GUID" {
            InModuleScope EasyPIM {
                # Arrange
                $displayName = "Marketing Unit"
                $auId = "11111111-2222-3333-4444-555555555555"
                Mock invoke-graph {
                    return [PSCustomObject]@{
                        value = @(
                            [PSCustomObject]@{
                                id = $auId
                                displayName = $displayName
                            }
                        )
                    }
                }
                
                # Act
                $result = Resolve-EasyPIMDirectoryScope -Scope $displayName
                
                # Assert
                $result | Should -Be "/administrativeUnits/$auId"
                Should -Invoke invoke-graph -Times 1 -Exactly
            }
        }
        
        It "Should query Graph with escaped display name filter" {
            InModuleScope EasyPIM {
                # Arrange
                $displayName = "Test's Unit"
                $auId = "aaaabbbb-cccc-dddd-eeee-ffffffffffff"
                Mock invoke-graph {
                    param($Endpoint, $Filter)
                    # Verify single quotes are escaped as ''
                    $Filter | Should -Match "Test''s Unit"
                    return [PSCustomObject]@{
                        value = @(
                            [PSCustomObject]@{ id = $auId; displayName = $displayName }
                        )
                    }
                }
                
                # Act
                $result = Resolve-EasyPIMDirectoryScope -Scope $displayName
                
                # Assert
                $result | Should -Be "/administrativeUnits/$auId"
            }
        }
        
        It "Should throw error when no administrative unit matches display name" {
            InModuleScope EasyPIM {
                # Arrange
                $displayName = "NonExistentUnit"
                Mock invoke-graph {
                    return @{ value = @() }
                }
                
                # Act & Assert
                { Resolve-EasyPIMDirectoryScope -Scope $displayName } | 
                    Should -Throw "*No administrative unit found matching*"
            }
        }
        
        It "Should throw error when multiple administrative units match" {
            InModuleScope EasyPIM {
                # Arrange
                $displayName = "DuplicateUnit"
                Mock invoke-graph {
                    return [PSCustomObject]@{
                        value = @(
                            [PSCustomObject]@{ id = "11111111-1111-1111-1111-111111111111"; displayName = $displayName }
                            [PSCustomObject]@{ id = "22222222-2222-2222-2222-222222222222"; displayName = $displayName }
                        )
                    }
                }
                
                # Act & Assert
                { Resolve-EasyPIMDirectoryScope -Scope $displayName } | 
                    Should -Throw "*Multiple administrative units matched*"
            }
        }
        
        It "Should include matched display names in multiple match error" {
            InModuleScope EasyPIM {
                # Arrange
                $displayName = "TestUnit"
                Mock invoke-graph {
                    return [PSCustomObject]@{
                        value = @(
                            [PSCustomObject]@{ id = "id1"; displayName = "TestUnit Alpha" }
                            [PSCustomObject]@{ id = "id2"; displayName = "TestUnit Beta" }
                        )
                    }
                }
                
                # Act & Assert
                { Resolve-EasyPIMDirectoryScope -Scope $displayName } | 
                    Should -Throw "*TestUnit Alpha*TestUnit Beta*"
            }
        }
    }
    
    Context "When handling Graph API errors" {
        
        It "Should throw error with context when Graph query fails" {
            InModuleScope EasyPIM {
                # Arrange
                $displayName = "ErrorTestUnit"
                Mock invoke-graph {
                    throw "Network timeout"
                }
                
                # Act & Assert
                { Resolve-EasyPIMDirectoryScope -Scope $displayName } | 
                    Should -Throw "*Failed to query administrative units*"
            }
        }
        
        It "Should include original exception message in error" {
            InModuleScope EasyPIM {
                # Arrange
                $displayName = "FailUnit"
                Mock invoke-graph {
                    throw "Specific Graph error message"
                }
                
                # Act & Assert
                { Resolve-EasyPIMDirectoryScope -Scope $displayName } | 
                    Should -Throw "*Specific Graph error message*"
            }
        }
        
        It "Should use custom ErrorContext in error messages" {
            InModuleScope EasyPIM {
                # Arrange
                $displayName = "TestUnit"
                Mock invoke-graph {
                    throw "Test error"
                }
                
                # Act & Assert
                { Resolve-EasyPIMDirectoryScope -Scope $displayName -ErrorContext "CustomContext" } | 
                    Should -Throw "CustomContext*"
            }
        }
    }
    
    Context "When validating response structure" {
        
        It "Should handle response with direct id property" {
            InModuleScope EasyPIM {
                # Arrange
                $displayName = "DirectIdUnit"
                $auId = "direct-id-test-1234-5678-90abcdef1234"
                Mock invoke-graph {
                    return [PSCustomObject]@{
                        id = $auId
                        displayName = $displayName
                    }
                }
                
                # Act
                $result = Resolve-EasyPIMDirectoryScope -Scope $displayName
                
                # Assert
                $result | Should -Be "/administrativeUnits/$auId"
            }
        }
        
        It "Should throw error when response has no id property" {
            InModuleScope EasyPIM {
                # Arrange
                $displayName = "NoIdUnit"
                Mock invoke-graph {
                    return [PSCustomObject]@{
                        value = @(
                            [PSCustomObject]@{ displayName = $displayName }
                        )
                    }
                }
                
                # Act & Assert
                # Function checks if 'id' property exists, then checks if it's null
                { Resolve-EasyPIMDirectoryScope -Scope $displayName } | 
                    Should -Throw "*did not include an 'id' property*"
            }
        }
        
        It "Should throw error when id property is null" {
            InModuleScope EasyPIM {
                # Arrange
                $displayName = "NullIdUnit"
                Mock invoke-graph {
                    return [PSCustomObject]@{
                        value = @(
                            [PSCustomObject]@{ id = $null; displayName = $displayName }
                        )
                    }
                }
                
                # Act & Assert
                { Resolve-EasyPIMDirectoryScope -Scope $displayName } | 
                    Should -Throw "*did not include an 'id' property*"
            }
        }
    }
}
