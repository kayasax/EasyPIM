<#
.SYNOPSIS
    Unit test for get-Groupconfig internal helper.
.DESCRIPTION
    Tests PIM group configuration retrieval from Microsoft Graph.
    Validates policy retrieval, config parsing for owner/member roles, and error handling.
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

# Module imported by test runner (pester-modern.ps1)

Describe "get-Groupconfig" {
    
    BeforeAll {
        # Import module
        $modulePath = Join-Path $PSScriptRoot "..\..\..\EasyPIM\EasyPIM.psd1"
        Import-Module $modulePath -Force -ErrorAction Stop
    }
    
    Context "When retrieving group owner configuration" {
        
        It "Should return config for group owner role" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "group-1234-5678-90ab-cdef12345678"
                $roleType = "owner"
                $policyId = "policy-owner-1234-5678-90ab"
                
                Mock invoke-graph {
                    return @{
                        value = @{
                            policyid = $policyId
                            policy = @{
                                rules = @(
                                    @{ id = "Expiration_EndUser_Assignment"; maximumDuration = "PT8H" }
                                    @{ id = "Enablement_EndUser_Assignment"; enabledRules = @("MFA", "Justification") }
                                    @{ id = "Enablement_Admin_Assignment"; enabledRules = @() }
                                    @{ id = "AuthenticationContext_EndUser_Assignment"; isEnabled = $false; claimValue = $null }
                                    @{ 
                                        id = "Approval_EndUser_Assignment"
                                        setting = @{
                                            isapprovalrequired = $false
                                            approvalStages = @{ primaryApprovers = @() }
                                        }
                                    }
                                    @{ id = "Expiration_Admin_Eligibility"; isExpirationRequired = $false; maximumDuration = "P365D" }
                                    @{ id = "Expiration_Admin_Assignment"; isExpirationRequired = $true; maximumDuration = "P180D" }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type $roleType
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.PolicyID | Should -Be $policyId
                $result.ActivationDuration | Should -Be "PT8H"
            }
        }
        
        It "Should return config for group member role" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "member-group-1234-5678-90ab"
                $roleType = "member"
                $policyId = "policy-member-1234-5678-90ab"
                
                Mock invoke-graph {
                    return @{
                        value = @{
                            policyid = $policyId
                            policy = @{
                                rules = @(
                                    @{ id = "Expiration_EndUser_Assignment"; maximumDuration = "PT4H" }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type $roleType
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.PolicyID | Should -Be $policyId
                $result.ActivationDuration | Should -Be "PT4H"
            }
        }
    }
    
    Context "When parsing policy rules" {
        
        It "Should parse enablement rules correctly" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "enablement-test-1234-5678"
                Mock invoke-graph {
                    return @{
                        value = @{
                            policyid = "policy-id"
                            policy = @{
                                rules = @(
                                    @{ id = "Enablement_EndUser_Assignment"; enabledRules = @("MultiFactorAuthentication", "Justification", "Ticketing") }
                                    @{ id = "Enablement_Admin_Assignment"; enabledRules = @("Justification") }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type "owner"
                
                # Assert
                $result.EnablementRules | Should -Match "MultiFactorAuthentication"
                $result.EnablementRules | Should -Match "Justification"
                $result.ActiveAssignmentRequirement | Should -Be "Justification"
            }
        }
        
        It "Should parse authentication context when enabled" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "authcontext-test-1234-5678"
                Mock invoke-graph {
                    return @{
                        value = @{
                            policyid = "policy-id"
                            policy = @{
                                rules = @(
                                    @{ id = "AuthenticationContext_EndUser_Assignment"; isEnabled = $true; claimValue = "C1" }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type "member"
                
                # Assert
                $result.AuthenticationContext_Enabled | Should -Be $true
                $result.AuthenticationContext_Value | Should -Be "C1"
            }
        }
        
        It "Should handle approvers with groupMembers type" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "approver-group-test-1234"
                Mock invoke-graph {
                    return @{
                        value = @{
                            policyid = "policy-id"
                            policy = @{
                                rules = @(
                                    @{ 
                                        id = "Approval_EndUser_Assignment"
                                        setting = @{
                                            isapprovalrequired = $true
                                            approvalStages = @{
                                                primaryApprovers = @(
                                                    @{
                                                        '@odata.type' = '#microsoft.graph.groupMembers'
                                                        groupID = "approver-group-123"
                                                        description = "Approver Group"
                                                    }
                                                )
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type "owner"
                
                # Assert
                $result.ApprovalRequired | Should -Be $true
                $result.Approvers | Should -Match "approver-group-123"
                $result.Approvers | Should -Match "group"
            }
        }
        
        It "Should handle approvers with singleUser type" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "approver-user-test-1234"
                Mock invoke-graph {
                    return @{
                        value = @{
                            policyid = "policy-id"
                            policy = @{
                                rules = @(
                                    @{ 
                                        id = "Approval_EndUser_Assignment"
                                        setting = @{
                                            isapprovalrequired = $true
                                            approvalStages = @{
                                                primaryApprovers = @(
                                                    @{
                                                        '@odata.type' = '#microsoft.graph.singleUser'
                                                        userID = "user-789"
                                                        description = "Approver User"
                                                    }
                                                )
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type "member"
                
                # Assert
                $result.ApprovalRequired | Should -Be $true
                $result.Approvers | Should -Match "user-789"
                $result.Approvers | Should -Match "user"
            }
        }
        
        It "Should handle multiple approvers correctly" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "multi-approver-test-1234"
                Mock invoke-graph {
                    return @{
                        value = @{
                            policyid = "policy-id"
                            policy = @{
                                rules = @(
                                    @{ 
                                        id = "Approval_EndUser_Assignment"
                                        setting = @{
                                            isapprovalrequired = $true
                                            approvalStages = @{
                                                primaryApprovers = @(
                                                    @{
                                                        '@odata.type' = '#microsoft.graph.singleUser'
                                                        userID = "user-1"
                                                        description = "First Approver"
                                                    }
                                                    @{
                                                        '@odata.type' = '#microsoft.graph.groupMembers'
                                                        groupID = "group-1"
                                                        description = "Approver Group"
                                                    }
                                                )
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type "owner"
                
                # Assert
                $result.Approvers | Should -Match "user-1"
                $result.Approvers | Should -Match "group-1"
            }
        }
        
        It "Should handle empty approvers list" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "no-approver-test-1234"
                Mock invoke-graph {
                    return @{
                        value = @{
                            policyid = "policy-id"
                            policy = @{
                                rules = @(
                                    @{ 
                                        id = "Approval_EndUser_Assignment"
                                        setting = @{
                                            isapprovalrequired = $false
                                            approvalStages = @{
                                                primaryApprovers = @()
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type "member"
                
                # Assert
                $result.ApprovalRequired | Should -Be $false
                $result.Approvers | Should -BeNullOrEmpty
            }
        }
    }
    
    Context "When handling eligibility and assignment duration" {
        
        It "Should set AllowPermanentEligibleAssignment to false when expiration required" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "expiry-test-1234-5678"
                Mock invoke-graph {
                    return @{
                        value = @{
                            policyid = "policy-id"
                            policy = @{
                                rules = @(
                                    @{ id = "Expiration_Admin_Eligibility"; isExpirationRequired = $true; maximumDuration = "P90D" }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type "owner"
                
                # Assert
                $result.AllowPermanentEligibleAssignment | Should -Be "false"
                $result.MaximumEligibleAssignmentDuration | Should -Be "P90D"
            }
        }
        
        It "Should set AllowPermanentEligibleAssignment to true when expiration not required" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "no-expiry-test-1234-5678"
                Mock invoke-graph {
                    return @{
                        value = @{
                            policyid = "policy-id"
                            policy = @{
                                rules = @(
                                    @{ id = "Expiration_Admin_Eligibility"; isExpirationRequired = $false; maximumDuration = "P365D" }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type "member"
                
                # Assert
                $result.AllowPermanentEligibleAssignment | Should -Be "true"
            }
        }
        
        It "Should handle active assignment expiration correctly" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "active-assign-test-1234"
                Mock invoke-graph {
                    return @{
                        value = @{
                            policyid = "policy-id"
                            policy = @{
                                rules = @(
                                    @{ id = "Expiration_Admin_Assignment"; isExpirationRequired = $false; maximumDuration = "P180D" }
                                )
                            }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type "owner"
                
                # Assert
                $result.AllowPermanentActiveAssignment | Should -Be "true"
                $result.MaximumActiveAssignmentDuration | Should -Be "P180D"
            }
        }
    }
    
    Context "When validating Graph API calls" {
        
        It "Should call roleManagementPolicyAssignments with correct filter for owner" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "filter-owner-test-1234"
                $roleType = "owner"
                $script:capturedEndpoint = $null
                Mock invoke-graph {
                    param($Endpoint)
                    $script:capturedEndpoint = $Endpoint
                    return @{
                        value = @{
                            policyid = "policy-id"
                            policy = @{ rules = @() }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type $roleType
                
                # Assert - check filter was built into endpoint URL
                $script:capturedEndpoint | Should -Match "roleManagementPolicyAssignments"
                $script:capturedEndpoint | Should -Match "scopeId eq '$groupId'"
                $script:capturedEndpoint | Should -Match "scopeType eq 'Group'"
                $script:capturedEndpoint | Should -Match "roleDefinitionId eq '$roleType'"
            }
        }
        
        It "Should call roleManagementPolicyAssignments with correct filter for member" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "filter-member-test-1234"
                $roleType = "member"
                $script:capturedEndpoint = $null
                Mock invoke-graph {
                    param($Endpoint)
                    $script:capturedEndpoint = $Endpoint
                    return @{
                        value = @{
                            policyid = "policy-id"
                            policy = @{ rules = @() }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type $roleType
                
                # Assert - check filter was built into endpoint URL
                $script:capturedEndpoint | Should -Match "roleManagementPolicyAssignments"
                $script:capturedEndpoint | Should -Match "scopeId eq '$groupId'"
                $script:capturedEndpoint | Should -Match "roleDefinitionId eq '$roleType'"
            }
        }
        
        It "Should use expand parameter to get policy with rules" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "expand-test-1234-5678"
                Mock invoke-graph {
                    param($Endpoint)
                    $Endpoint | Should -Match '\$expand=policy\(\$expand=rules\)'
                    return @{
                        value = @{
                            policyid = "policy-id"
                            policy = @{ rules = @() }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type "owner"
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "When handling errors" {
        
        It "Should call Mycatch on exception" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "error-test-1234-5678"
                Mock invoke-graph {
                    throw "Graph API error"
                }
                Mock Mycatch { }
                
                # Act
                $result = get-Groupconfig -id $groupId -type "owner"
                
                # Assert
                Should -Invoke Mycatch -Times 1 -Exactly
            }
        }
    }
    
    Context "When validating output structure" {
        
        It "Should return PSCustomObject with expected properties" {
            InModuleScope EasyPIM {
                # Arrange
                $groupId = "output-test-1234-5678"
                Mock invoke-graph {
                    return @{
                        value = @{
                            policyid = "policy-id"
                            policy = @{ rules = @() }
                        }
                    }
                }
                
                # Act
                $result = get-Groupconfig -id $groupId -type "owner"
                
                # Assert
                $result.PSObject.Properties.Name | Should -Contain 'PolicyID'
                $result.PSObject.Properties.Name | Should -Contain 'ActivationDuration'
                $result.PSObject.Properties.Name | Should -Contain 'EnablementRules'
                $result.PSObject.Properties.Name | Should -Contain 'ActiveAssignmentRequirement'
                $result.PSObject.Properties.Name | Should -Contain 'ApprovalRequired'
            }
        }
    }
}
