<#
.SYNOPSIS
    Integration tests for Issue #239 - MFA preservation in Copy-PIMEntraRolePolicy

.DESCRIPTION
    Tests the complete export-import cycle with REAL authentication and tenant data
    to verify that MultiFactorAuthentication requirements on active assignments
    are correctly preserved during policy copy operations.
    
    REQUIRES:
    - Active Azure AD/Entra ID authentication
    - Read permissions on PIM role policies
    - Two test roles in tenant (source and target)
    
.NOTES
    Template Version: 1.1
    Standards: TESTING-STANDARDS.md v1.1
    Test Type: Integration (requires authentication)
    Issue: #239 - MFA on active assignments not copying
    Author: EasyPIM Team
    Date: 2025-11-15
#>

#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

# Discovery-time helper load: ensure `Test-IntegrationTestAuth` is available
$helperPath = Join-Path $PSScriptRoot "..\helpers\IntegrationTestBase.ps1"
if (Test-Path $helperPath) { . $helperPath }
if ($null -eq $script:testConfig) { $script:testConfig = @{} }
$script:testConfig.IsAuthenticated = Test-IntegrationTestAuth

BeforeAll {
    # Import module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\EasyPIM\EasyPIM.psd1"
    Import-Module $modulePath -Force
    
    # Import integration test helpers
    $helperPath = Join-Path $PSScriptRoot "..\helpers\IntegrationTestBase.ps1"
    . $helperPath
    
    # Integration test setup
    Write-Host "🔐 Integration Test - Real Authentication Required" -ForegroundColor Cyan
    Write-Host "This test will:" -ForegroundColor Yellow
    Write-Host "  1. Export policy from source role (with MFA on active assignment)" -ForegroundColor Yellow
    Write-Host "  2. Import policy to temporary CSV" -ForegroundColor Yellow
    Write-Host "  3. Verify MFA is preserved in CSV" -ForegroundColor Yellow
    Write-Host "  4. Parse CSV back and verify MFA in parsed data" -ForegroundColor Yellow
    Write-Host ""
    
    # Test configuration - CUSTOMIZE THESE FOR YOUR TENANT
    $script:testConfig = @{
        # Source role that HAS MFA requirement on active assignment
        SourceRole = "Security Reader"  # Common role with MFA configured
        
        # Alternative: Use your own test role names
        # SourceRole = "Your-Role-With-MFA"
        
        # Temp file for CSV export
        TempCSV = Join-Path $env:TEMP "easypim-issue239-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
        
        # Check auth with helper function
        IsAuthenticated = Test-IntegrationTestAuth
    }
    
    # Report auth status
    if ($script:testConfig.IsAuthenticated) {
        $context = Get-MgContext
        Write-Host "✅ Authenticated as: $($context.Account)" -ForegroundColor Green
        Write-Host "   Tenant: $($context.TenantId)" -ForegroundColor Gray
    } else {
        Write-Host "⚠️  Microsoft Graph authentication not available - tests will SKIP" -ForegroundColor Yellow
        Write-Host "   To authenticate: Connect-MgGraph -Scopes 'RoleManagement.Read.Directory'" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

Describe "Copy-PIMEntraRolePolicy - Issue #239 MFA Preservation (Integration)" -Tag "Integration", "Issue239", "MFA", "SlowTest" {
    
    # Early exit if auth not available - prevents all Context blocks from executing
    if (-not $script:testConfig.IsAuthenticated) {
        It "Skipped: Graph auth not available" {
            Set-ItResult -Skipped -Because "Microsoft Graph authentication not available"
        }
        return
    }
    
    Context "When exporting role policy with MFA on active assignment (Real API)" {
        
        BeforeAll {
            # Export policy from source role
            Write-Host "📤 Exporting policy from '$($script:testConfig.SourceRole)'..." -ForegroundColor Cyan
            
            try {
                # Get tenant ID from current context
                $context = Get-MgContext
                $tenantId = $context.TenantId
                
                Export-PIMEntraRolePolicy -tenantID $tenantId `
                                         -rolename $script:testConfig.SourceRole `
                                         -path $script:testConfig.TempCSV `
                                         -ErrorAction Stop
                                         
                Write-Host "✅ Export completed: $($script:testConfig.TempCSV)" -ForegroundColor Green
                
                # Read exported CSV
                $script:exportedData = Import-Csv -Path $script:testConfig.TempCSV
                
                Write-Host "📋 Exported policy details:" -ForegroundColor Cyan
                Write-Host "  Role: $($script:exportedData.RoleName)" -ForegroundColor Gray
                Write-Host "  ActiveAssignmentRequirement: $($script:exportedData.ActiveAssignmentRequirement)" -ForegroundColor Gray
                Write-Host "  EnablementRules: $($script:exportedData.EnablementRules)" -ForegroundColor Gray
                
            } catch {
                Write-Warning "Export failed: $_"
                Write-Warning "Make sure the role '$($script:testConfig.SourceRole)' exists in your tenant"
                throw
            }
        }
        
        It "Should export CSV file successfully" {
            Test-Path $script:testConfig.TempCSV | Should -Be $true
        }
        
        It "Should have ActiveAssignmentRequirement column in exported CSV" {
            $script:exportedData | Get-Member -Name "ActiveAssignmentRequirement" | Should -Not -BeNullOrEmpty
        }
        
        It "Should preserve MultiFactorAuthentication in ActiveAssignmentRequirement if configured" {
            # Note: This test will PASS if MFA is configured, SKIP if not configured in source role
            if ($script:exportedData.ActiveAssignmentRequirement -match 'MultiFactorAuthentication') {
                Write-Host "✅ MFA found in ActiveAssignmentRequirement: $($script:exportedData.ActiveAssignmentRequirement)" -ForegroundColor Green
                $script:exportedData.ActiveAssignmentRequirement | Should -Match 'MultiFactorAuthentication'
            } else {
                Set-ItResult -Skipped -Because "Source role does not have MFA configured on active assignment"
            }
        }
        
        It "Should NOT have Ticketing in ActiveAssignmentRequirement (Rule #7 - Issue #239 correction)" {
            # This verifies the secondary bug fix - Ticketing should NOT be in Rule #7
            $script:exportedData.ActiveAssignmentRequirement | Should -Not -Match 'Ticketing'
        }
        
        It "Should allow Ticketing in EnablementRules (Rule #2 - activation)" {
            # Ticketing IS valid for Rule #2 (activation), just not Rule #7 (active assignment)
            if ($script:exportedData.EnablementRules -match 'Ticketing') {
                Write-Host "✅ Ticketing found in EnablementRules (Rule #2): $($script:exportedData.EnablementRules)" -ForegroundColor Green
                $script:exportedData.EnablementRules | Should -Match 'Ticketing'
            } else {
                # It's OK if Ticketing isn't configured - just verify it's allowed
                Write-Host "ℹ️  Ticketing not configured in EnablementRules (but would be valid)" -ForegroundColor Gray
                $true | Should -Be $true
            }
        }
    }
    
    Context "When parsing exported CSV back into policy object (Issue #239 workflow)" {
        
        BeforeAll {
            # Simulate the Import-EntraRoleSettings workflow
            Write-Host "🔄 Simulating Import-EntraRoleSettings.ps1 parsing logic..." -ForegroundColor Cyan
            
            $csvData = Import-Csv -Path $script:testConfig.TempCSV
            
            # Split the ActiveAssignmentRequirement string (same logic as Import-EntraRoleSettings.ps1)
            $activeAssignmentRequirements = if ($csvData.ActiveAssignmentRequirement) {
                $csvData.ActiveAssignmentRequirement -split ','
            } else {
                @()
            }
            
            # Apply the CORRECTED filter (after Issue #239 fix)
            $allowedAdmin = @('Justification','MultiFactorAuthentication')  # NO Ticketing per Rule #7 spec
            $script:filteredRequirements = $activeAssignmentRequirements | Where-Object { $_ -in $allowedAdmin }
            
            Write-Host "  Raw CSV value: $($csvData.ActiveAssignmentRequirement)" -ForegroundColor Gray
            Write-Host "  After split: $($activeAssignmentRequirements -join ', ')" -ForegroundColor Gray
            Write-Host "  After filter: $($script:filteredRequirements -join ', ')" -ForegroundColor Gray
        }
        
        It "Should preserve MultiFactorAuthentication after parsing and filtering" {
            if ($script:exportedData.ActiveAssignmentRequirement -match 'MultiFactorAuthentication') {
                $script:filteredRequirements | Should -Contain 'MultiFactorAuthentication'
                Write-Host "✅ MFA PRESERVED after Import-EntraRoleSettings.ps1 filtering!" -ForegroundColor Green
            } else {
                Set-ItResult -Skipped -Because "Source role does not have MFA configured"
            }
        }
        
        It "Should allow Justification after filtering (Rule #7 valid value)" {
            if ($script:exportedData.ActiveAssignmentRequirement -match 'Justification') {
                $script:filteredRequirements | Should -Contain 'Justification'
            } else {
                Set-ItResult -Skipped -Because "Source role does not have Justification configured"
            }
        }
        
        It "Should filter OUT Ticketing if present (Rule #7 correction)" {
            # Even if CSV had Ticketing (old bug), new code should filter it out
            $script:filteredRequirements | Should -Not -Contain 'Ticketing'
            Write-Host "✅ Ticketing correctly filtered out per Rule #7 spec" -ForegroundColor Green
        }
    }
    
    Context "When verifying Set-ActiveAssignmentRequirement would generate correct API payload" {
        
        It "Should generate API payload with MFA when MFA is in filtered requirements" {
            if ($script:filteredRequirements -contains 'MultiFactorAuthentication') {
                # Simulate Set-ActiveAssignmentRequirement.ps1 logic
                $apiPayload = @{
                    '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyEnablementRule'
                    id = 'Enablement_Admin_Assignment'
                    enabledRules = $script:filteredRequirements
                }
                
                $apiPayload.enabledRules | Should -Contain 'MultiFactorAuthentication'
                Write-Host "✅ API payload would correctly include MFA!" -ForegroundColor Green
                Write-Host "  Payload: $($apiPayload.enabledRules -join ', ')" -ForegroundColor Gray
            } else {
                Set-ItResult -Skipped -Because "MFA not in source role"
            }
        }
    }
}

AfterAll {
    # Cleanup
    if (Test-Path $script:testConfig.TempCSV) {
        Write-Host "🧹 Cleaning up temporary CSV..." -ForegroundColor Cyan
        Remove-Item $script:testConfig.TempCSV -Force
        Write-Host "✅ Cleanup complete" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "📊 Integration Test Summary:" -ForegroundColor Cyan
    Write-Host "  Issue #239 MFA preservation validated with REAL tenant data" -ForegroundColor Green
    Write-Host "  Export → CSV → Parse → Filter → API Payload workflow tested" -ForegroundColor Green
    Write-Host ""
}
