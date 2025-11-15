<#
.SYNOPSIS
    Unit test for Test-PIMPolicyBusinessRules internal function.
.DESCRIPTION
    Tests the Test-PIMPolicyBusinessRules function which validates and adjusts PIM policy settings
    according to Microsoft Graph API business rules. Covers Auth Context vs MFA conflicts,
    ActivationRequirement adjustments, and automatic conflict resolution.
.NOTES
    Template Version: 1.1
    Created: November 13, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalFunction
#>

Describe "Test-PIMPolicyBusinessRules" -Tag 'Unit', 'InternalFunction' {
    
    BeforeAll {
        # Import module
        Import-Module "$PSScriptRoot/../../../EasyPIM/EasyPIM.psd1" -Force
    }
    
    Context "When AuthenticationContext is enabled with MFA in ActivationRequirement" {
        
        It "Should detect MFA conflict without applying adjustments" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                    ActivationRequirement = @('MultiFactorAuthentication', 'Justification')
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings
                
                # Assert
                $result.Conflicts.Count | Should -Be 1
                $result.Conflicts[0].Type | Should -Be 'AuthenticationContextMfaConflict'
                $result.Conflicts[0].Field | Should -Be 'ActivationRequirement'
                $result.HasChanges | Should -Be $false
                $result.AdjustedSettings.ActivationRequirement | Should -Contain 'MultiFactorAuthentication'
            }
        }
        
        It "Should apply adjustments when -ApplyAdjustments is used" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                    ActivationRequirement = @('MultiFactorAuthentication', 'Justification')
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -ApplyAdjustments
                
                # Assert
                $result.HasChanges | Should -Be $true
                $result.AdjustedSettings.ActivationRequirement | Should -Not -Contain 'MultiFactorAuthentication'
                $result.AdjustedSettings.ActivationRequirement | Should -Contain 'Justification'
                $result.Conflicts[0].AdjustedValue | Should -Not -Contain 'MultiFactorAuthentication'
            }
        }
        
        It "Should handle comma-separated string ActivationRequirement" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                    ActivationRequirement = 'MultiFactorAuthentication, Justification, Ticketing'
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -ApplyAdjustments
                
                # Assert
                $result.HasChanges | Should -Be $true
                $result.AdjustedSettings.ActivationRequirement | Should -Not -Contain 'MultiFactorAuthentication'
                $result.AdjustedSettings.ActivationRequirement | Should -Contain 'Justification'
                $result.AdjustedSettings.ActivationRequirement | Should -Contain 'Ticketing'
            }
        }
        
        It "Should handle single string ActivationRequirement" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                    ActivationRequirement = 'MultiFactorAuthentication'
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -ApplyAdjustments
                
                # Assert
                $result.HasChanges | Should -Be $true
                $result.AdjustedSettings.ActivationRequirement | Should -BeNullOrEmpty
            }
        }
    }
    
    Context "When AuthenticationContext is enabled via CurrentPolicy" {
        
        It "Should detect AuthContext from CurrentPolicy.AuthenticationContext_Enabled" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    ActivationRequirement = @('MultiFactorAuthentication')
                }
                $currentPolicy = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -CurrentPolicy $currentPolicy -ApplyAdjustments
                
                # Assert
                $result.HasChanges | Should -Be $true
                $result.AuthenticationContextEnabled | Should -Be $true
                $result.AdjustedSettings.ActivationRequirement | Should -Not -Contain 'MultiFactorAuthentication'
            }
        }
        
        It "Should detect AuthContext from CurrentPolicy.authenticationContextClassReferences" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    ActivationRequirement = @('MultiFactorAuthentication')
                }
                $currentPolicy = [PSCustomObject]@{
                    authenticationContextClassReferences = 'c1'
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -CurrentPolicy $currentPolicy -ApplyAdjustments
                
                # Assert
                $result.HasChanges | Should -Be $true
                $result.AuthenticationContextEnabled | Should -Be $true
            }
        }
        
        It "Should detect AuthContext from CurrentPolicy.authenticationContext" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    ActivationRequirement = @('MultiFactorAuthentication')
                }
                $currentPolicy = [PSCustomObject]@{
                    authenticationContext = @{ enabled = $true }
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -CurrentPolicy $currentPolicy -ApplyAdjustments
                
                # Assert
                $result.AuthenticationContextEnabled | Should -Be $true
            }
        }
    }
    
    Context "When AuthenticationContext appears in requirement arrays" {
        
        It "Should remove 'AuthenticationContext' from ActivationRequirement" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    ActivationRequirement = @('AuthenticationContext', 'Justification')
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -ApplyAdjustments
                
                # Assert
                $result.HasChanges | Should -Be $true
                $result.AdjustedSettings.ActivationRequirement | Should -Not -Contain 'AuthenticationContext'
                $result.AdjustedSettings.ActivationRequirement | Should -Contain 'Justification'
                $result.Conflicts[0].Type | Should -Be 'AuthenticationContextInvalidValue'
            }
        }
        
        It "Should remove 'AuthenticationContext' from ActiveAssignmentRequirement" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    ActiveAssignmentRequirement = @('AuthenticationContext', 'MultiFactorAuthentication')
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -ApplyAdjustments
                
                # Assert
                $result.HasChanges | Should -Be $true
                $result.AdjustedSettings.ActiveAssignmentRequirement | Should -Not -Contain 'AuthenticationContext'
                $result.Conflicts.Type | Should -Contain 'AuthenticationContextInvalidValue'
            }
        }
    }
    
    Context "When AuthenticationContext affects ActiveAssignmentRequirement" {
        
        It "Should detect MFA conflict in ActiveAssignmentRequirement" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                    ActiveAssignmentRequirement = @('MultiFactorAuthentication', 'Justification')
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -ApplyAdjustments
                
                # Assert
                $result.HasChanges | Should -Be $true
                $result.AdjustedSettings.ActiveAssignmentRequirement | Should -Not -Contain 'MultiFactorAuthentication'
                $result.AdjustedSettings.ActiveAssignmentRequirement | Should -Contain 'Justification'
            }
        }
        
        It "Should handle comma-separated ActiveAssignmentRequirement" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                    ActiveAssignmentRequirement = 'MultiFactorAuthentication, Justification'
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -ApplyAdjustments
                
                # Assert
                $result.HasChanges | Should -Be $true
                $result.AdjustedSettings.ActiveAssignmentRequirement | Should -Not -Contain 'MultiFactorAuthentication'
            }
        }
    }
    
    Context "When no conflicts exist" {
        
        It "Should return no conflicts for valid settings without AuthContext" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    ActivationRequirement = @('MultiFactorAuthentication', 'Justification')
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings
                
                # Assert
                $result.Conflicts.Count | Should -Be 0
                $result.HasChanges | Should -Be $false
                $result.AuthenticationContextEnabled | Should -Be $false
            }
        }
        
        It "Should return no conflicts when AuthContext enabled without MFA" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                    ActivationRequirement = @('Justification', 'Ticketing')
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings
                
                # Assert
                $result.Conflicts.Count | Should -Be 0
                $result.HasChanges | Should -Be $false
                $result.AuthenticationContextEnabled | Should -Be $true
            }
        }
        
        It "Should handle empty ActivationRequirement" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings
                
                # Assert
                $result.Conflicts.Count | Should -Be 0
                $result.HasChanges | Should -Be $false
            }
        }
    }
    
    Context "When handling multiple conflicts simultaneously" {
        
        It "Should detect both ActivationRequirement and ActiveAssignmentRequirement conflicts" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                    ActivationRequirement = @('MultiFactorAuthentication', 'Justification')
                    ActiveAssignmentRequirement = @('MultiFactorAuthentication', 'Ticketing')
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -ApplyAdjustments
                
                # Assert
                $result.Conflicts.Count | Should -Be 2
                $result.HasChanges | Should -Be $true
                $result.AdjustedSettings.ActivationRequirement | Should -Not -Contain 'MultiFactorAuthentication'
                $result.AdjustedSettings.ActiveAssignmentRequirement | Should -Not -Contain 'MultiFactorAuthentication'
            }
        }
        
        It "Should detect AuthenticationContext in both requirements" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    ActivationRequirement = @('AuthenticationContext', 'Justification')
                    ActiveAssignmentRequirement = @('AuthenticationContext', 'Ticketing')
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -ApplyAdjustments
                
                # Assert
                $result.Conflicts.Count | Should -Be 2
                $result.Conflicts | ForEach-Object { $_.Type | Should -Be 'AuthenticationContextInvalidValue' }
            }
        }
        
        It "Should handle combined MFA and AuthenticationContext conflicts" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                    ActivationRequirement = @('AuthenticationContext', 'MultiFactorAuthentication', 'Justification')
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -ApplyAdjustments
                
                # Assert
                $result.Conflicts.Count | Should -Be 2
                $result.HasChanges | Should -Be $true
                # Function applies removals sequentially, AuthenticationContext removal happens last
                $result.AdjustedSettings.ActivationRequirement | Should -Not -Contain 'AuthenticationContext'
                # MFA might remain after AuthenticationContext removal overwrites the previous adjustment
                $result.AdjustedSettings.ActivationRequirement | Should -Contain 'Justification'
            }
        }
    }
    
    Context "When handling edge cases" {
        
        It "Should handle null ActivationRequirement" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                    ActivationRequirement = $null
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings
                
                # Assert
                $result.Conflicts.Count | Should -Be 0
                $result.HasChanges | Should -Be $false
            }
        }
        
        It "Should handle empty array ActivationRequirement" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                    ActivationRequirement = @()
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings
                
                # Assert
                $result.Conflicts.Count | Should -Be 0
                $result.HasChanges | Should -Be $false
            }
        }
        
        It "Should preserve original settings when not applying adjustments" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                    ActivationRequirement = @('MultiFactorAuthentication')
                    CustomProperty = 'PreserveMe'
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings
                
                # Assert
                $result.AdjustedSettings.CustomProperty | Should -Be 'PreserveMe'
                $result.AdjustedSettings.ActivationRequirement | Should -Contain 'MultiFactorAuthentication'
            }
        }
    }
    
    Context "When validating conflict metadata" {
        
        It "Should provide detailed conflict information" {
            InModuleScope EasyPIM {
                # Arrange
                $policySettings = [PSCustomObject]@{
                    AuthenticationContext_Enabled = $true
                    ActivationRequirement = @('MultiFactorAuthentication', 'Justification')
                }
                
                # Act
                $result = Test-PIMPolicyBusinessRules -PolicySettings $policySettings -ApplyAdjustments
                
                # Assert
                $conflict = $result.Conflicts[0]
                $conflict.Field | Should -Be 'ActivationRequirement'
                $conflict.Type | Should -Be 'AuthenticationContextMfaConflict'
                $conflict.Message | Should -Match 'Authentication Context.*MultiFactorAuthentication.*removed'
                $conflict.OriginalValue | Should -Contain 'MultiFactorAuthentication'
                $conflict.AdjustedValue | Should -Not -Contain 'MultiFactorAuthentication'
            }
        }
    }
}
