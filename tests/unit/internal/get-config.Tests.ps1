<#
.SYNOPSIS
    Unit test for get-config internal helper.

.DESCRIPTION
    Tests the get-config function which retrieves PIM role policy configuration for Azure Resource roles.
    Covers subscription scope extraction, 3-step ARM API workflow (roleDefinition → assignment → policy),
    error handling for missing roles, and copyFrom parameter logic.
    
    NOTE: This is a complex 212-line function with extensive policy parsing. This test file focuses on:
    - Core logic: scope parsing (lines 24-30)
    - API workflow: 3-step pattern (lines 36-65)
    - Error handling: missing roles, empty responses
    - CopyFrom parameter: alternate processing logic
    
    Full policy parsing validation is better suited for integration tests.

.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

Describe "get-config" -Tag 'Unit', 'InternalHelper' {
    
    BeforeAll {
        InModuleScope EasyPIM {
            # Mock Get-PIMAzureEnvironmentEndpoint
            Mock Get-PIMAzureEnvironmentEndpoint {
                return "https://management.azure.com"
            }
            
            # Mock Log function (used for error logging)
            Mock Log { }
            
            # Mock MyCatch (error handler)
            Mock MyCatch {
                param($exception)
                throw $exception
            }
        }
    }
    
    Context "When extracting subscription ID from scope" {
        
        It "Should extract subscription ID from subscription scope" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "subscriptions/12345678-1234-1234-1234-123456789abc"
                $rolename = "Contributor"
                
                Mock Invoke-ARM {
                    param($restURI, $method, $body, $SubscriptionId)
                    
                    # Verify SubscriptionId was extracted and passed
                    if ($restURI -like "*roleDefinitions*") {
                        $SubscriptionId | Should -Be "12345678-1234-1234-1234-123456789abc"
                        return @{ value = @(@{ id = "role-id-123" }) }
                    }
                    if ($restURI -like "*roleManagementPolicyAssignments*") {
                        return @{ value = @(@{ properties = @{ policyId = "policy-id-123" } }) }
                    }
                    if ($restURI -like "*policy-id-123*") {
                        return @{
                            properties = @{
                                rules = @(
                                    @{ id = "Expiration_EndUser_Assignment"; maximumduration = "PT8H" }
                                    @{ id = "Enablement_EndUser_Assignment"; enabledRules = @("MultiFactorAuthentication") }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-config -scope $scope -rolename $rolename
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should handle management group scope without subscription ID" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "providers/Microsoft.Management/managementGroups/mg-root"
                $rolename = "Reader"
                
                Mock Invoke-ARM {
                    param($restURI, $method, $body, $SubscriptionId)
                    
                    # Verify SubscriptionId is null for MG scope
                    if ($restURI -like "*roleDefinitions*") {
                        $SubscriptionId | Should -BeNullOrEmpty
                        return @{ value = @(@{ id = "role-id-mg" }) }
                    }
                    if ($restURI -like "*roleManagementPolicyAssignments*") {
                        return @{ value = @(@{ properties = @{ policyId = "policy-id-mg" } }) }
                    }
                    if ($restURI -like "*policy-id-mg*") {
                        return @{
                            properties = @{
                                rules = @(
                                    @{ id = "Expiration_EndUser_Assignment"; maximumduration = "PT4H" }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-config -scope $scope -rolename $rolename
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should handle malformed scope gracefully" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "invalid-scope-format"
                $rolename = "Owner"
                
                Mock Invoke-ARM {
                    param($restURI, $method, $body, $SubscriptionId)
                    
                    if ($restURI -like "*roleDefinitions*") {
                        return @{ value = @(@{ id = "role-id-invalid" }) }
                    }
                    if ($restURI -like "*roleManagementPolicyAssignments*") {
                        return @{ value = @(@{ properties = @{ policyId = "policy-id-invalid" } }) }
                    }
                    if ($restURI -like "*policy-id-invalid*") {
                        return @{
                            properties = @{
                                rules = @(
                                    @{ id = "Expiration_EndUser_Assignment"; maximumduration = "PT2H" }
                                )
                            }
                        }
                    }
                }
                
                # Act & Assert - Should not throw, just proceed without subId
                { get-config -scope $scope -rolename $rolename } | Should -Not -Throw
            }
        }
    }
    
    Context "When executing 3-step ARM API workflow" {
        
        It "Should call step 1: Get role definition" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "subscriptions/test-sub-id"
                $rolename = "Virtual Machine Contributor"
                
                Mock Invoke-ARM {
                    param($restURI, $method, $body, $SubscriptionId)
                    
                    if ($restURI -like "*roleDefinitions*") {
                        return @{ value = @(@{ id = "/subscriptions/test-sub-id/providers/Microsoft.Authorization/roleDefinitions/role-123" }) }
                    }
                    if ($restURI -like "*roleManagementPolicyAssignments*") {
                        return @{ value = @(@{ properties = @{ policyId = "policy-123" } }) }
                    }
                    if ($restURI -like "*policy-123*") {
                        return @{ properties = @{ rules = @() } }
                    }
                }
                
                # Act
                get-config -scope $scope -rolename $rolename
                
                # Assert - Verify step 1 called with correct filter
                Should -Invoke Invoke-ARM -ParameterFilter {
                    $restURI -like "*roleDefinitions*" -and
                    $restURI -like "*filter=roleName eq 'Virtual Machine Contributor'*" -and
                    $method -eq "get"
                }
            }
        }
        
        It "Should call step 2: Get role management policy assignment" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "subscriptions/test-sub-id"
                $rolename = "Storage Blob Data Reader"
                
                Mock Invoke-ARM {
                    param($restURI, $method)
                    
                    if ($restURI -like "*roleDefinitions*") {
                        return @{ value = @(@{ id = "role-def-456" }) }
                    }
                    if ($restURI -like "*roleManagementPolicyAssignments*") {
                        return @{ value = @(@{ properties = @{ policyId = "policy-456" } }) }
                    }
                    if ($restURI -like "*policy-456*") {
                        return @{ properties = @{ rules = @() } }
                    }
                }
                
                # Act
                get-config -scope $scope -rolename $rolename
                
                # Assert - Verify step 2 called with roleDefinitionId filter
                Should -Invoke Invoke-ARM -ParameterFilter {
                    $restURI -like "*roleManagementPolicyAssignments*" -and
                    $restURI -like "*filter=roleDefinitionId eq 'role-def-456'*"
                }
            }
        }
        
        It "Should call step 3: Get policy details" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "subscriptions/test-sub-id"
                $rolename = "Key Vault Administrator"
                
                Mock Invoke-ARM {
                    param($restURI, $method)
                    
                    if ($restURI -like "*roleDefinitions*") {
                        return @{ value = @(@{ id = "role-789" }) }
                    }
                    if ($restURI -like "*roleManagementPolicyAssignments*") {
                        return @{ value = @(@{ properties = @{ policyId = "policy-789" } }) }
                    }
                    if ($restURI -like "*policy-789*") {
                        return @{
                            properties = @{
                                rules = @(
                                    @{ id = "Expiration_EndUser_Assignment"; maximumduration = "PT12H" }
                                )
                            }
                        }
                    }
                }
                
                # Act
                get-config -scope $scope -rolename $rolename
                
                # Assert - Verify step 3 called with policy ID
                Should -Invoke Invoke-ARM -ParameterFilter {
                    $restURI -like "*policy-789*" -and
                    $restURI -like "*api-version=2020-10-01*"
                }
            }
        }
        
        It "Should pass through all 3 API workflow steps successfully" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "subscriptions/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
                $rolename = "Contributor"
                
                Mock Invoke-ARM {
                    param($restURI, $method)
                    
                    if ($restURI -like "*roleDefinitions*") {
                        return @{ value = @(@{ id = "test-role-id" }) }
                    }
                    if ($restURI -like "*roleManagementPolicyAssignments*") {
                        return @{ value = @(@{ properties = @{ policyId = "test-policy-id" } }) }
                    }
                    if ($restURI -like "*test-policy-id*") {
                        return @{
                            properties = @{
                                rules = @(
                                    @{ id = "Expiration_EndUser_Assignment"; maximumduration = "PT24H" }
                                    @{ id = "Enablement_EndUser_Assignment"; enabledRules = @("Justification", "MultiFactorAuthentication") }
                                    @{ id = "Approval_EndUser_Assignment"; setting = @{ isapprovalrequired = $true } }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-config -scope $scope -rolename $rolename
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.ActivationDuration | Should -Be "PT24H"
                $result.EnablementRules | Should -Match "Justification"
                $result.ApprovalRequired | Should -Be $true
                Should -Invoke Invoke-ARM -Times 3 -Exactly
            }
        }
    }
    
    Context "When role is not found" {
        
        It "Should log error and return early when roleID is empty" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "subscriptions/test-sub-id"
                $rolename = "NonExistentRole"
                
                Mock Invoke-ARM {
                    return @{ value = @() }  # Empty result
                }
                
                Mock Log { }
                
                # Act
                $result = get-config -scope $scope -rolename $rolename
                
                # Assert
                $result | Should -BeNullOrEmpty
                Should -Invoke Log -Times 1 -ParameterFilter {
                    $msg -like "*Error getting config of NonExistentRole*"
                }
            }
        }
        
        It "Should log error and return early when roleID is null" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "subscriptions/test-sub-id"
                $rolename = "MissingRole"
                
                Mock Invoke-ARM {
                    return @{ value = $null }
                }
                
                Mock Log { }
                
                # Act
                $result = get-config -scope $scope -rolename $rolename
                
                # Assert
                $result | Should -BeNullOrEmpty
                Should -Invoke Log -Times 1
            }
        }
    }
    
    Context "When using copyFrom parameter" {
        
        It "Should follow alternate file-based processing path" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "subscriptions/test-sub-id"
                $rolename = "Reader"
                $copyFrom = $true
                
                # Create a mock script path variable that get-config uses
                $script:_scriptPath = $TestDrive
                
                Mock Invoke-ARM {
                    param($restURI)
                    
                    if ($restURI -like "*roleDefinitions*") {
                        return @{ value = @(@{ id = "reader-role-id" }) }
                    }
                    if ($restURI -like "*roleManagementPolicyAssignments*") {
                        return @{ value = @(@{ properties = @{ policyId = "reader-policy-id" } }) }
                    }
                    return $null
                }
                
                Mock Get-AzAccessToken {
                    return @{ Token = "mock-token-12345" }
                }
                
                Mock Invoke-RestMethod {
                    param($Uri, $Method, $Headers, $OutFile)
                    
                    # Create temp.json file with sample content
                    '{"properties":{"rules":[{"id":"test-rule"}],"effectiveRules":[]}}' | Out-File -FilePath $OutFile
                }
                
                Mock Get-Content {
                    return '{"properties":{"rules":[{"id":"test-rule"}],"effectiveRules":[]}}'
                }
                
                Mock Remove-Item { }
                
                # Act
                $result = get-config -scope $scope -rolename $rolename -copyFrom $copyFrom
                
                # Assert - Should have called Get-AzAccessToken and processed differently
                Should -Invoke Get-AzAccessToken -Times 1
                Should -Invoke Invoke-RestMethod -Times 1
            }
        }
        
        It "Should extract rules JSON when copyFrom is provided" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "subscriptions/copy-test-sub"
                $rolename = "Owner"
                $copyFrom = $true
                $script:_scriptPath = $TestDrive
                
                Mock Invoke-ARM {
                    param($restURI)
                    
                    if ($restURI -like "*roleDefinitions*") {
                        return @{ value = @(@{ id = "owner-role-id" }) }
                    }
                    if ($restURI -like "*roleManagementPolicyAssignments*") {
                        return @{ value = @(@{ properties = @{ policyId = "owner-policy-id" } }) }
                    }
                }
                
                Mock Get-AzAccessToken {
                    return @{ Token = "mock-copy-token" }
                }
                
                Mock Invoke-RestMethod {
                    param($OutFile)
                    '{"something":"before","rules":[{"rule1":"data"}],"effectiveRules":[],"after":"something"}' | Out-File -FilePath $OutFile
                }
                
                Mock Get-Content {
                    return '{"something":"before","rules":[{"rule1":"data"}],"effectiveRules":[],"after":"something"}'
                }
                
                Mock Remove-Item { }
                
                # Act
                $result = get-config -scope $scope -rolename $rolename -copyFrom $copyFrom
                
                # Assert - Result should be processed rules JSON
                $result | Should -Match 'rule1'
                Should -Invoke Remove-Item -Times 1 -ParameterFilter {
                    $Path -like "*temp.json"
                }
            }
        }
    }
    
    Context "When handling authentication context" {
        
        It "Should set AuthenticationContext_Value to null when disabled" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "subscriptions/auth-test-sub"
                $rolename = "Test Role"
                
                Mock Invoke-ARM {
                    param($restURI)
                    
                    if ($restURI -like "*roleDefinitions*") {
                        return @{ value = @(@{ id = "auth-role-id" }) }
                    }
                    if ($restURI -like "*roleManagementPolicyAssignments*") {
                        return @{ value = @(@{ properties = @{ policyId = "auth-policy-id" } }) }
                    }
                    if ($restURI -like "*auth-policy-id*") {
                        return @{
                            properties = @{
                                rules = @(
                                    @{ 
                                        id = "AuthenticationContext_EndUser_Assignment"
                                        isEnabled = $false
                                        claimValue = "should-be-ignored"
                                    }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-config -scope $scope -rolename $rolename
                
                # Assert - Issue #54 fix: should set value to null when disabled
                $result.AuthenticationContext_Enabled | Should -Be $false
                $result.AuthenticationContext_Value | Should -BeNullOrEmpty
            }
        }
        
        It "Should set AuthenticationContext_Value when enabled" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "subscriptions/auth-enabled-sub"
                $rolename = "Sensitive Role"
                
                Mock Invoke-ARM {
                    param($restURI)
                    
                    if ($restURI -like "*roleDefinitions*") {
                        return @{ value = @(@{ id = "sensitive-role-id" }) }
                    }
                    if ($restURI -like "*roleManagementPolicyAssignments*") {
                        return @{ value = @(@{ properties = @{ policyId = "sensitive-policy-id" } }) }
                    }
                    if ($restURI -like "*sensitive-policy-id*") {
                        return @{
                            properties = @{
                                rules = @(
                                    @{ 
                                        id = "AuthenticationContext_EndUser_Assignment"
                                        isEnabled = $true
                                        claimValue = "c1"
                                    }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-config -scope $scope -rolename $rolename
                
                # Assert
                $result.AuthenticationContext_Enabled | Should -Be $true
                $result.AuthenticationContext_Value | Should -Be "c1"
            }
        }
    }
    
    Context "When API errors occur" {
        
        It "Should call MyCatch on exception and re-throw" {
            InModuleScope EasyPIM {
                # Arrange
                $scope = "subscriptions/error-sub"
                $rolename = "ErrorRole"
                
                Mock Invoke-ARM {
                    throw "Network connection failed"
                }
                
                Mock MyCatch {
                    param($exception)
                    throw "Caught: $($exception.Exception.Message)"
                }
                
                # Act & Assert
                { get-config -scope $scope -rolename $rolename } | Should -Throw "*Caught: Network connection failed*"
                Should -Invoke MyCatch -Times 1
            }
        }
    }
}
