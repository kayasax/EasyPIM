<#
.SYNOPSIS
    Regression test for Issue #239 - MFA on active assignments not preserved during policy copy.
.DESCRIPTION
    Tests that Import-EntraRoleSettings properly preserves MultiFactorAuthentication in 
    ActiveAssignmentRequirement when importing Entra role policies. This was a security bug
    where MFA requirements were silently dropped during Copy-PIMEntraRolePolicy operations.
    
    Bug: Import-EntraRoleSettings filtered out MFA from $allowedAdmin array
    Fix: Added 'MultiFactorAuthentication' to allowed admin enablement rules
    Reference: https://github.com/kayasax/EasyPIM/issues/239
    Microsoft Docs: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#assignment-rules
.NOTES
    Template Version: 1.1
    Created: November 14, 2025
    Standards: See tests/TESTING-STANDARDS.md
    Tags: Modern, UnitTest, Internal, Issue239, SecurityBug
#>

Describe "Import-EntraRoleSettings - Issue #239 MFA Preservation" -Tag 'Unit', 'Internal', 'Issue239' {
    
    BeforeAll {
        # Import module in test scope
        Import-Module "$PSScriptRoot\..\..\..\EasyPIM\EasyPIM.psd1" -Force
    }
    
    Context "When importing role policy with MFA on active assignment (Issue #239)" {
        
        It "Should preserve MultiFactorAuthentication in ActiveAssignmentRequirement" {
            InModuleScope EasyPIM {
                # Arrange: Create temporary CSV with MFA in ActiveAssignmentRequirement
                $tempCsv = Join-Path $env:TEMP "test-issue239-mfa-$(Get-Random).csv"
                
                # Mock CSV content with MFA on active assignment (this was being dropped)
                $csvContent = @"
"RoleName","roleID","PolicyID","ActivationDuration","EnablementRules","ActiveAssignmentRequirement","AuthenticationContext_Enabled","AuthenticationContext_Value","ApprovalRequired","Approvers","AllowPermanentEligibleAssignment","MaximumEligibleAssignmentDuration","AllowPermanentActiveAssignment","MaximumActiveAssignmentDuration"
"Test Role","test-role-id","test-policy-id","PT8H","MultiFactorAuthentication,Justification","MultiFactorAuthentication,Justification","False","","False","","False","P180D","False","P30D"
"@
                $csvContent | Out-File -FilePath $tempCsv -Encoding utf8
                
                # Mock invoke-graph to avoid real API calls
                Mock invoke-graph {
                    param($Endpoint)
                    
                    if ($Endpoint -match "roleDefinitions") {
                        return @{
                            value = @(
                                @{ id = "test-role-id"; displayName = "Test Role" }
                            )
                        }
                    }
                    elseif ($Endpoint -match "roleManagementPolicyAssignments") {
                        return @{
                            value = @{
                                policyId = "test-policy-id"
                            }
                        }
                    }
                    return @{}
                }
                
                # Mock Update-EntraRolePolicy to capture the rules being set
                Mock Update-EntraRolePolicy {
                    param($PolicyId, $Rules)
                    # Store rules for assertion
                    $script:CapturedRules = $Rules
                }
                
                # Mock Set-ActiveAssignmentRequirement to verify it's called with MFA
                Mock Set-ActiveAssignmentRequirement {
                    param($ActiveAssignmentRequirement, [switch]$entraRole)
                    
                    # Convert to array if needed
                    if ($ActiveAssignmentRequirement -is [string]) {
                        $ActiveAssignmentRequirement = @($ActiveAssignmentRequirement -split ',')
                    }
                    
                    # Store for assertion
                    $script:CapturedMFARequirements = $ActiveAssignmentRequirement
                    
                    # Return mock rule JSON
                    return '{"id":"Enablement_Admin_Assignment","enabledRules":["MultiFactorAuthentication","Justification"]}'
                } -ParameterFilter { 
                    $ActiveAssignmentRequirement -contains 'MultiFactorAuthentication' 
                }
                
                # Act: Import the CSV
                try {
                    Import-EntraRoleSettings -Path $tempCsv
                } catch {
                    # Suppress errors from mocked functions
                }
                
                # Assert: Verify Set-ActiveAssignmentRequirement was called with MFA
                Assert-MockCalled Set-ActiveAssignmentRequirement -Times 1 -Exactly -ParameterFilter {
                    $ActiveAssignmentRequirement -contains 'MultiFactorAuthentication'
                }
                
                # Verify MFA was actually captured (not filtered out)
                $script:CapturedMFARequirements | Should -Contain 'MultiFactorAuthentication'
                $script:CapturedMFARequirements | Should -Contain 'Justification'
                
                # Cleanup
                if (Test-Path $tempCsv) { Remove-Item $tempCsv -Force }
            }
        }
        
        It "Should allow MFA alone in ActiveAssignmentRequirement" {
            InModuleScope EasyPIM {
                # Arrange: CSV with only MFA (no Justification)
                $tempCsv = Join-Path $env:TEMP "test-issue239-mfa-only-$(Get-Random).csv"
                
                $csvContent = @"
"RoleName","roleID","PolicyID","ActivationDuration","EnablementRules","ActiveAssignmentRequirement","AuthenticationContext_Enabled","AuthenticationContext_Value","ApprovalRequired","Approvers","AllowPermanentEligibleAssignment","MaximumEligibleAssignmentDuration","AllowPermanentActiveAssignment","MaximumActiveAssignmentDuration"
"Test Role","test-role-id","test-policy-id","PT8H","Justification","MultiFactorAuthentication","False","","False","","False","P180D","False","P30D"
"@
                $csvContent | Out-File -FilePath $tempCsv -Encoding utf8
                
                # Mock dependencies
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match "roleDefinitions") {
                        return @{ value = @(@{ id = "test-role-id"; displayName = "Test Role" }) }
                    }
                    elseif ($Endpoint -match "roleManagementPolicyAssignments") {
                        return @{ value = @{ policyId = "test-policy-id" } }
                    }
                    return @{}
                }
                
                Mock Update-EntraRolePolicy { }
                
                Mock Set-ActiveAssignmentRequirement {
                    param($ActiveAssignmentRequirement, [switch]$entraRole)
                    $script:CapturedMFAOnly = $ActiveAssignmentRequirement
                    return '{"id":"Enablement_Admin_Assignment","enabledRules":["MultiFactorAuthentication"]}'
                } -ParameterFilter {
                    $ActiveAssignmentRequirement -contains 'MultiFactorAuthentication'
                }
                
                # Act
                try {
                    Import-EntraRoleSettings -Path $tempCsv
                } catch { }
                
                # Assert: MFA should be preserved even when alone
                $script:CapturedMFAOnly | Should -Contain 'MultiFactorAuthentication'
                
                # Cleanup
                if (Test-Path $tempCsv) { Remove-Item $tempCsv -Force }
            }
        }
        
        It "Should allow mixed requirements with MFA and Justification (Ticketing NOT supported)" {
            InModuleScope EasyPIM {
                # Arrange: CSV with MFA and Justification (Ticketing is NOT supported for Rule #7)
                $tempCsv = Join-Path $env:TEMP "test-issue239-mixed-$(Get-Random).csv"
                
                $csvContent = @"
"RoleName","roleID","PolicyID","ActivationDuration","EnablementRules","ActiveAssignmentRequirement","AuthenticationContext_Enabled","AuthenticationContext_Value","ApprovalRequired","Approvers","AllowPermanentEligibleAssignment","MaximumEligibleAssignmentDuration","AllowPermanentActiveAssignment","MaximumActiveAssignmentDuration"
"Test Role","test-role-id","test-policy-id","PT8H","Justification","MultiFactorAuthentication,Justification","False","","False","","False","P180D","False","P30D"
"@
                $csvContent | Out-File -FilePath $tempCsv -Encoding utf8
                
                # Mock dependencies
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match "roleDefinitions") {
                        return @{ value = @(@{ id = "test-role-id"; displayName = "Test Role" }) }
                    }
                    elseif ($Endpoint -match "roleManagementPolicyAssignments") {
                        return @{ value = @{ policyId = "test-policy-id" } }
                    }
                    return @{}
                }
                
                Mock Update-EntraRolePolicy { }
                
                Mock Set-ActiveAssignmentRequirement {
                    param($ActiveAssignmentRequirement, [switch]$entraRole)
                    $script:CapturedMixed = $ActiveAssignmentRequirement
                    return '{"id":"Enablement_Admin_Assignment","enabledRules":["MultiFactorAuthentication","Justification"]}'
                } -ParameterFilter {
                    $ActiveAssignmentRequirement -contains 'MultiFactorAuthentication' -and
                    $ActiveAssignmentRequirement -contains 'Justification'
                }
                
                # Act
                try {
                    Import-EntraRoleSettings -Path $tempCsv
                } catch { }
                
                # Assert: Both requirements should be preserved (Ticketing filtered out if present)
                $script:CapturedMixed | Should -Contain 'MultiFactorAuthentication'
                $script:CapturedMixed | Should -Contain 'Justification'
                $script:CapturedMixed.Count | Should -Be 2
                
                # Cleanup
                if (Test-Path $tempCsv) { Remove-Item $tempCsv -Force }
            }
        }
        
        It "Should call Set-ActiveAssignmentRequirement when ActiveAssignmentRequirement is empty (Issue #245)" {
            InModuleScope EasyPIM {
                # Arrange: CSV with no active assignment requirements
                $tempCsv = Join-Path $env:TEMP "test-issue239-empty-$(Get-Random).csv"
                
                $csvContent = @"
"RoleName","roleID","PolicyID","ActivationDuration","EnablementRules","ActiveAssignmentRequirement","AuthenticationContext_Enabled","AuthenticationContext_Value","ApprovalRequired","Approvers","AllowPermanentEligibleAssignment","MaximumEligibleAssignmentDuration","AllowPermanentActiveAssignment","MaximumActiveAssignmentDuration"
"Test Role","test-role-id","test-policy-id","PT8H","Justification","","False","","False","","False","P180D","False","P30D"
"@
                $csvContent | Out-File -FilePath $tempCsv -Encoding utf8
                
                # Mock dependencies
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match "roleDefinitions") {
                        return @{ value = @(@{ id = "test-role-id"; displayName = "Test Role" }) }
                    }
                    elseif ($Endpoint -match "roleManagementPolicyAssignments") {
                        return @{ value = @{ policyId = "test-policy-id" } }
                    }
                    return @{}
                }
                
                Mock Update-EntraRolePolicy { }
                Mock Set-ActiveAssignmentRequirement { }
                
                # Act
                try {
                    Import-EntraRoleSettings -Path $tempCsv
                } catch { }
                
                # Assert: Should be called with empty array to clear settings (Issue #245)
                Assert-MockCalled Set-ActiveAssignmentRequirement -Times 1 -Exactly -ParameterFilter {
                    $ActiveAssignmentRequirement.Count -eq 0
                }
                
                # Cleanup
                if (Test-Path $tempCsv) { Remove-Item $tempCsv -Force }
            }
        }
    }
    
    Context "When validating Copy-PIMEntraRolePolicy workflow (Issue #239 scenario)" {
        
        It "Should preserve MFA through export-import cycle" {
            InModuleScope EasyPIM {
                # This test simulates what Copy-PIMEntraRolePolicy does internally:
                # 1. Export source role to CSV
                # 2. Import CSV to target role
                # Bug was: MFA lost during step 2
                
                # Arrange: Simulate exported CSV with MFA
                $tempCsv = Join-Path $env:TEMP "test-issue239-copy-$(Get-Random).csv"
                
                # This represents what get-EntraRoleconfig exports
                $exportedContent = @"
"RoleName","roleID","PolicyID","ActivationDuration","EnablementRules","ActiveAssignmentRequirement","AuthenticationContext_Enabled","AuthenticationContext_Value","ApprovalRequired","Approvers","AllowPermanentEligibleAssignment","MaximumEligibleAssignmentDuration","AllowPermanentActiveAssignment","MaximumActiveAssignmentDuration"
"Source Role","source-role-id","source-policy-id","PT8H","MultiFactorAuthentication,Justification","MultiFactorAuthentication,Justification","False","","True","@{id=""approver-123"";description=""Manager"";userType=""user""}","False","P180D","False","P30D"
"@
                $exportedContent | Out-File -FilePath $tempCsv -Encoding utf8
                
                # Mock dependencies
                Mock invoke-graph {
                    param($Endpoint)
                    if ($Endpoint -match "roleDefinitions") {
                        return @{ value = @(@{ id = "target-role-id"; displayName = "Target Role" }) }
                    }
                    elseif ($Endpoint -match "roleManagementPolicyAssignments") {
                        return @{ value = @{ policyId = "target-policy-id" } }
                    }
                    return @{}
                }
                
                Mock Update-EntraRolePolicy {
                    param($PolicyId, $Rules)
                    $script:FinalRules = $Rules
                }
                
                # Track if MFA reaches Set-ActiveAssignmentRequirement
                $script:MFAPreserved = $false
                Mock Set-ActiveAssignmentRequirement {
                    param($ActiveAssignmentRequirement, [switch]$entraRole)
                    if ($ActiveAssignmentRequirement -contains 'MultiFactorAuthentication') {
                        $script:MFAPreserved = $true
                    }
                    return '{"id":"Enablement_Admin_Assignment","enabledRules":["MultiFactorAuthentication","Justification"]}'
                }
                
                # Act: Import (simulates what Copy-PIMEntraRolePolicy does)
                try {
                    Import-EntraRoleSettings -Path $tempCsv
                } catch { }
                
                # Assert: MFA should survive the import process
                $script:MFAPreserved | Should -Be $true -Because "MFA requirement must not be dropped during policy copy (Issue #239)"
                
                # Cleanup
                if (Test-Path $tempCsv) { Remove-Item $tempCsv -Force }
            }
        }
    }
}
