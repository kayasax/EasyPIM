<#
.SYNOPSIS
    Unit test for Get-EntraRoleConfig internal helper.
.DESCRIPTION
    Tests Entra role configuration retrieval from Microsoft Graph.
    Validates role resolution, policy retrieval, config parsing, and error handling.
.NOTES
    Template Version: 1.1
    Created: November 12, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, InternalHelper
#>

# Module imported by test runner (pester-modern.ps1)

Describe "Get-EntraRoleConfig" {
    
    BeforeAll {
        # Import module
        $modulePath = Join-Path $PSScriptRoot "..\..\..\EasyPIM\EasyPIM.psd1"
        Import-Module $modulePath -Force -ErrorAction Stop
    }
    
    Context "When retrieving valid role configuration" {
        
        It "Should return config for Global Administrator role" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "Global Administrator"
                $roleId = "globaladmin-1234-5678-90ab-cdef"
                $policyId = "policy-1234-5678-90ab-cdef12345678"
                
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match 'roleDefinitions') {
                        return @{
                            value = @(
                                @{ id = $roleId; displayName = $roleName }
                            )
                        }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicyAssignments') {
                        return @{ value = @{ policyID = $policyId } }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicies') {
                        return @{
                            value = @(
                                @{ id = "Expiration_EndUser_Assignment"; maximumDuration = "PT8H" }
                                @{ id = "Enablement_EndUser_Assignment"; enabledRules = @("MFA", "Justification") }
                                @{ id = "Enablement_Admin_Assignment"; enabledRules = @() }
                                @{ id = "AuthenticationContext_EndUser_Assignment"; isEnabled = $false; claimValue = $null }
                                @{ id = "Approval_EndUser_Assignment"; setting = @{ isapprovalrequired = $false; approvalStages = @{ primaryApprovers = @() } } }
                                @{ id = "Expiration_Admin_Eligibility"; isExpirationRequired = $false; maximumDuration = "P365D" }
                                @{ id = "Expiration_Admin_Assignment"; isExpirationRequired = $true; maximumDuration = "P180D" }
                            )
                        }
                    }
                }
                
                # Act
                $result = Get-EntraRoleConfig -rolename $roleName
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.PolicyID | Should -Be $policyId
                $result.ActivationDuration | Should -Be "PT8H"
            }
        }
        
        It "Should resolve role ID with case-insensitive match" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "security reader"
                $roleId = "secreader-1234-5678-90ab-cdef"
                
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match 'roleDefinitions') {
                        return @{
                            value = @(
                                @{ id = $roleId; displayName = "Security Reader" }
                            )
                        }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicyAssignments') {
                        return @{ value = @{ policyID = "policy-id" } }
                    }
                    else {
                        return @{ value = @() }
                    }
                }
                
                # Act
                $result = Get-EntraRoleConfig -rolename $roleName
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result.roleID | Should -Be $roleId
            }
        }
        
        It "Should parse enablement rules correctly" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "Test Role"
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match 'roleDefinitions') {
                        return @{ value = @( @{ id = "role-id"; displayName = $roleName } ) }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicyAssignments') {
                        return @{ value = @{ policyID = "policy-id" } }
                    }
                    else {
                        return @{
                            value = @(
                                @{ id = "Enablement_EndUser_Assignment"; enabledRules = @("MultiFactorAuthentication", "Justification", "Ticketing") }
                                @{ id = "Enablement_Admin_Assignment"; enabledRules = @("Justification") }
                            )
                        }
                    }
                }
                
                # Act
                $result = Get-EntraRoleConfig -rolename $roleName
                
                # Assert
                $result.EnablementRules | Should -Match "MultiFactorAuthentication"
                $result.EnablementRules | Should -Match "Justification"
                $result.EnablementRules | Should -Match "Ticketing"
                $result.ActiveAssignmentRequirement | Should -Be "Justification"
            }
        }
        
        It "Should parse authentication context correctly" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "Auth Context Role"
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match 'roleDefinitions') {
                        return @{ value = @( @{ id = "role-id"; displayName = $roleName } ) }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicyAssignments') {
                        return @{ value = @{ policyID = "policy-id" } }
                    }
                    else {
                        return @{
                            value = @(
                                @{ id = "AuthenticationContext_EndUser_Assignment"; isEnabled = $true; claimValue = "C1" }
                            )
                        }
                    }
                }
                
                # Act
                $result = Get-EntraRoleConfig -rolename $roleName
                
                # Assert
                $result.AuthenticationContext_Enabled | Should -Be $true
                $result.AuthenticationContext_Value | Should -Be "C1"
            }
        }
        
        It "Should handle approvers with group type" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "Approval Role"
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match 'roleDefinitions') {
                        return @{ value = @( @{ id = "role-id"; displayName = $roleName } ) }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicyAssignments') {
                        return @{ value = @{ policyID = "policy-id" } }
                    }
                    else {
                        return @{
                            value = @(
                                @{ 
                                    id = "Approval_EndUser_Assignment"
                                    setting = @{
                                        isapprovalrequired = $true
                                        approvalStages = @{
                                            primaryApprovers = @(
                                                @{
                                                    '@odata.type' = '#microsoft.graph.groupMembers'
                                                    groupID = "group-123"
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
                
                # Act
                $result = Get-EntraRoleConfig -rolename $roleName
                
                # Assert
                $result.ApprovalRequired | Should -Be $true
                $result.Approvers | Should -Match "group-123"
                $result.Approvers | Should -Match "group"
            }
        }
        
        It "Should handle approvers with user type" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "User Approval Role"
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match 'roleDefinitions') {
                        return @{ value = @( @{ id = "role-id"; displayName = $roleName } ) }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicyAssignments') {
                        return @{ value = @{ policyID = "policy-id" } }
                    }
                    else {
                        return @{
                            value = @(
                                @{ 
                                    id = "Approval_EndUser_Assignment"
                                    setting = @{
                                        isapprovalrequired = $true
                                        approvalStages = @{
                                            primaryApprovers = @(
                                                @{
                                                    '@odata.type' = '#microsoft.graph.singleUser'
                                                    userID = "user-456"
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
                
                # Act
                $result = Get-EntraRoleConfig -rolename $roleName
                
                # Assert
                $result.ApprovalRequired | Should -Be $true
                $result.Approvers | Should -Match "user-456"
                $result.Approvers | Should -Match "user"
            }
        }
    }
    
    Context "When handling eligibility and assignment duration" {
        
        It "Should set AllowPermanentEligibleAssignment to false when expiration required" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "Expiry Role"
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match 'roleDefinitions') {
                        return @{ value = @( @{ id = "role-id"; displayName = $roleName } ) }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicyAssignments') {
                        return @{ value = @{ policyID = "policy-id" } }
                    }
                    else {
                        return @{
                            value = @(
                                @{ id = "Expiration_Admin_Eligibility"; isExpirationRequired = $true; maximumDuration = "P90D" }
                            )
                        }
                    }
                }
                
                # Act
                $result = Get-EntraRoleConfig -rolename $roleName
                
                # Assert
                $result.AllowPermanentEligibleAssignment | Should -Be "false"
                $result.MaximumEligibleAssignmentDuration | Should -Be "P90D"
            }
        }
        
        It "Should set AllowPermanentEligibleAssignment to true when expiration not required" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "No Expiry Role"
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match 'roleDefinitions') {
                        return @{ value = @( @{ id = "role-id"; displayName = $roleName } ) }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicyAssignments') {
                        return @{ value = @{ policyID = "policy-id" } }
                    }
                    else {
                        return @{
                            value = @(
                                @{ id = "Expiration_Admin_Eligibility"; isExpirationRequired = $false; maximumDuration = "P365D" }
                            )
                        }
                    }
                }
                
                # Act
                $result = Get-EntraRoleConfig -rolename $roleName
                
                # Assert
                $result.AllowPermanentEligibleAssignment | Should -Be "true"
            }
        }
        
        It "Should handle active assignment expiration correctly" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "Active Assignment Role"
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match 'roleDefinitions') {
                        return @{ value = @( @{ id = "role-id"; displayName = $roleName } ) }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicyAssignments') {
                        return @{ value = @{ policyID = "policy-id" } }
                    }
                    else {
                        return @{
                            value = @(
                                @{ id = "Expiration_Admin_Assignment"; isExpirationRequired = $false; maximumDuration = "P180D" }
                            )
                        }
                    }
                }
                
                # Act
                $result = Get-EntraRoleConfig -rolename $roleName
                
                # Assert
                $result.AllowPermanentActiveAssignment | Should -Be "true"
                $result.MaximumActiveAssignmentDuration | Should -Be "P180D"
            }
        }
    }
    
    Context "When handling errors" {
        
        It "Should throw error when role is not found" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "Nonexistent Role"
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match 'roleDefinitions') {
                        return @{ value = @() }
                    }
                }
                
                # Act & Assert
                { Get-EntraRoleConfig -rolename $roleName } | 
                    Should -Throw "*Role $roleName not found*"
            }
        }
        
        It "Should throw when roleID is null (role not found)" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "Null Role"
                Mock invoke-graph {
                    return @{ value = @() }
                }
                
                # Act & Assert
                # Function throws when role is not found
                { Get-EntraRoleConfig -rolename $roleName } | Should -Throw "*Role $roleName not found*"
            }
        }
        
        It "Should call Mycatch on exception" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "Error Role"
                Mock invoke-graph {
                    throw "Graph API error"
                }
                Mock Mycatch { }
                
                # Act
                $result = Get-EntraRoleConfig -rolename $roleName
                
                # Assert
                Should -Invoke Mycatch -Times 1 -Exactly
            }
        }
    }
    
    Context "When validating Graph API calls" {
        
        It "Should call roleDefinitions endpoint first" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "Test Role"
                $script:callOrder = @()
                Mock invoke-graph {
                    param($Endpoint)
                    # Track call order
                    if ($Endpoint -match 'roleDefinitions') {
                        $script:callOrder += 'roleDefinitions'
                        return @{ value = @( @{ id = "role-id"; displayName = $roleName } ) }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicyAssignments') {
                        $script:callOrder += 'policyAssignments'
                        return @{ value = @{ policyID = "policy-id" } }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicies/policy-id') {
                        $script:callOrder += 'policy'
                        return @{ rules = @() }
                    }
                    else {
                        return @{ value = @() }
                    }
                }
                
                # Act
                $result = Get-EntraRoleConfig -rolename $roleName
                
                # Assert
                $script:callOrder[0] | Should -Be 'roleDefinitions'
                $script:callOrder.Count | Should -BeGreaterThan 1
            }
        }
        
        It "Should call roleManagementPolicyAssignments with correct filter" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "Filter Test"
                $roleId = "filter-role-1234-5678"
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match 'roleDefinitions') {
                        return @{ value = @( @{ id = $roleId; displayName = $roleName } ) }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicyAssignments') {
                        $Endpoint | Should -Match "roleDefinitionId eq '$roleId'"
                        $Endpoint | Should -Match "scopeType eq 'DirectoryRole'"
                        $Endpoint | Should -Match "scopeId eq '/'"
                        return @{ value = @{ policyID = "policy-id" } }
                    }
                    else {
                        return @{ value = @() }
                    }
                }
                
                # Act
                $result = Get-EntraRoleConfig -rolename $roleName
                
                # Assert
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "When validating output structure" {
        
        It "Should return PSCustomObject with expected properties" {
            InModuleScope EasyPIM {
                # Arrange
                $roleName = "Output Test"
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match 'roleDefinitions') {
                        return @{ value = @( @{ id = "role-id"; displayName = $roleName } ) }
                    }
                    elseif ($Endpoint -match 'roleManagementPolicyAssignments') {
                        return @{ value = @{ policyID = "policy-id" } }
                    }
                    else {
                        return @{ value = @() }
                    }
                }
                
                # Act
                $result = Get-EntraRoleConfig -rolename $roleName
                
                # Assert
                $result.PSObject.Properties.Name | Should -Contain 'RoleName'
                $result.PSObject.Properties.Name | Should -Contain 'PolicyID'
                $result.PSObject.Properties.Name | Should -Contain 'ActivationDuration'
                $result.PSObject.Properties.Name | Should -Contain 'EnablementRules'
                $result.PSObject.Properties.Name | Should -Contain 'ApprovalRequired'
            }
        }
    }
}
