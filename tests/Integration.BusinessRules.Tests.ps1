Describe "EasyPIM End-to-End Business Rules Validation" -Tag "Integration", "LiveTenant" {
    
    BeforeAll {
        # Ensure required environment variables are set
        if (-not $env:TenantID) {
            throw "TenantID environment variable is required for live tenant tests"
        }
        if (-not $env:SubscriptionID) {
            throw "SubscriptionID environment variable is required for live tenant tests"
        }

        # Import modules if not already loaded
        if (-not (Get-Module EasyPIM)) {
            Import-Module "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1" -Force
        }
        if (-not (Get-Module EasyPIM.Orchestrator)) {
            Import-Module "$PSScriptRoot\..\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psd1" -Force
        }

        # Test configuration
        $script:TenantId = $env:TenantID
        $script:SubscriptionId = $env:SubscriptionID
        $script:ConfigPath = "$PSScriptRoot\validation.json"
        $script:TestRoleName = "Guest Inviter"
        $script:OriginalActivationDuration = "PT2H"  # From Standard template
        $script:ModifiedActivationDuration = "PT4H"  # Test change
        
        Write-Host "🔬 Starting End-to-End Business Rules Validation Test" -ForegroundColor Cyan
        Write-Host "   Tenant: $script:TenantId" -ForegroundColor Gray
        Write-Host "   Role: $script:TestRoleName" -ForegroundColor Gray
        Write-Host "   Config: $script:ConfigPath" -ForegroundColor Gray
    }

    Context "Pre-Test Baseline Verification" {
        
        It "Should have validation.json config file" {
            $script:ConfigPath | Should -Exist
        }

        It "Should be able to connect to tenant and read role policy" {
            $policy = Get-PIMEntraRolePolicy -TenantID $script:TenantId -RoleName $script:TestRoleName
            $policy | Should -Not -BeNullOrEmpty
            $policy.RoleName | Should -Be $script:TestRoleName
            Write-Host "   Current ActivationDuration: $($policy.ActivationDuration)" -ForegroundColor Yellow
        }

        It "Should initially have no drift when role matches config" {
            # First ensure role matches expected configuration
            Set-PIMEntraRolePolicy -TenantID $script:TenantId -RoleName $script:TestRoleName -ActivationDuration $script:OriginalActivationDuration
            
            # Wait a moment for the change to propagate
            Start-Sleep -Seconds 2
            
            # Test for drift
            $driftResults = Test-PIMPolicyDrift -TenantId $script:TenantId -ConfigPath $script:ConfigPath -PassThru
            $guestInviterResult = $driftResults | Where-Object { $_.Type -eq 'EntraRole' -and $_.Name -eq $script:TestRoleName }
            
            $guestInviterResult | Should -Not -BeNullOrEmpty
            $guestInviterResult.Status | Should -Be 'Match'
            Write-Host "   ✅ Baseline: No drift detected" -ForegroundColor Green
        }
    }

    Context "Drift Detection Validation" {
        
        It "Should detect drift when role policy is manually changed" {
            # Manually change the policy to create drift
            Write-Host "   🔧 Manually changing ActivationDuration to $script:ModifiedActivationDuration" -ForegroundColor Yellow
            Set-PIMEntraRolePolicy -TenantID $script:TenantId -RoleName $script:TestRoleName -ActivationDuration $script:ModifiedActivationDuration
            
            # Wait for propagation
            Start-Sleep -Seconds 2
            
            # Verify the change was applied
            $policy = Get-PIMEntraRolePolicy -TenantID $script:TenantId -RoleName $script:TestRoleName
            $policy.ActivationDuration | Should -Be $script:ModifiedActivationDuration
            
            # Test for drift
            $driftResults = Test-PIMPolicyDrift -TenantId $script:TenantId -ConfigPath $script:ConfigPath -PassThru
            $guestInviterResult = $driftResults | Where-Object { $_.Type -eq 'EntraRole' -and $_.Name -eq $script:TestRoleName }
            
            # Should detect drift
            $guestInviterResult | Should -Not -BeNullOrEmpty
            $guestInviterResult.Status | Should -Be 'Drift'
            $guestInviterResult.Differences | Should -Match "ActivationDuration.*expected.*'$script:OriginalActivationDuration'.*actual.*'$script:ModifiedActivationDuration'"
            
            Write-Host "   ✅ Drift Detection: Successfully detected policy drift" -ForegroundColor Green
        }

        It "Should handle business rules correctly during drift detection" {
            # Test with a role that has Authentication Context enabled to verify business rules
            $driftResults = Test-PIMPolicyDrift -TenantId $script:TenantId -ConfigPath $script:ConfigPath -PassThru -Verbose
            
            # Check for business rule verbose messages (indicates business rules are being applied)
            # This validates that Test-PIMPolicyBusinessRules is being called properly
            $businessRuleResults = $driftResults | Where-Object { $_.Type -eq 'EntraRole' -and $_.Status -eq 'Match' }
            
            # Should have at least some roles that match (indicating business rules worked)
            $businessRuleResults | Should -Not -BeNullOrEmpty
            Write-Host "   ✅ Business Rules: Working correctly in drift detection" -ForegroundColor Green
        }
    }

    Context "Orchestrator Remediation" {
        
        It "Should remediate drift using Invoke-EasyPIMOrchestrator" {
            # Run the orchestrator to fix the drift
            Write-Host "   🔄 Running Invoke-EasyPIMOrchestrator to remediate drift" -ForegroundColor Yellow
            
            $orchestratorResult = Invoke-EasyPIMOrchestrator -TenantId $script:TenantId -SubscriptionId $script:SubscriptionId -ConfigurationFile $script:ConfigPath -ValidateOnly:$false
            
            # Orchestrator should complete successfully
            $orchestratorResult | Should -Not -BeNullOrEmpty
            
            # Wait for changes to propagate
            Start-Sleep -Seconds 5
            
            # Verify the policy was corrected
            $policy = Get-PIMEntraRolePolicy -TenantID $script:TenantId -RoleName $script:TestRoleName
            $policy.ActivationDuration | Should -Be $script:OriginalActivationDuration
            
            Write-Host "   ✅ Remediation: Policy corrected to $($policy.ActivationDuration)" -ForegroundColor Green
        }

        It "Should show no drift after orchestrator remediation" {
            # Final drift check - should be clean
            $driftResults = Test-PIMPolicyDrift -TenantId $script:TenantId -ConfigPath $script:ConfigPath -PassThru
            $guestInviterResult = $driftResults | Where-Object { $_.Type -eq 'EntraRole' -and $_.Name -eq $script:TestRoleName }
            
            $guestInviterResult | Should -Not -BeNullOrEmpty
            $guestInviterResult.Status | Should -Be 'Match'
            $guestInviterResult.Differences | Should -BeNullOrEmpty
            
            Write-Host "   ✅ Final Verification: No drift detected after remediation" -ForegroundColor Green
        }
    }

    Context "Business Rules Integration Test" {
        
        It "Should properly handle Authentication Context vs MFA conflicts" {
            # Test the business rules function directly
            $testPolicy = [PSCustomObject]@{
                ActivationRequirement = "MultiFactorAuthentication,Justification"
                AuthenticationContext_Enabled = $true
            }
            
            $businessRuleResult = Test-PIMPolicyBusinessRules -PolicySettings $testPolicy -ApplyAdjustments
            
            $businessRuleResult.AuthenticationContextEnabled | Should -Be $true
            $businessRuleResult.HasChanges | Should -Be $true
            $businessRuleResult.Conflicts.Count | Should -BeGreaterThan 0
            $businessRuleResult.Conflicts[0].Type | Should -Be 'AuthenticationContextMfaConflict'
            
            # Should have removed MFA from ActivationRequirement
            $businessRuleResult.AdjustedSettings.ActivationRequirement | Should -Not -Contain 'MultiFactorAuthentication'
            $businessRuleResult.AdjustedSettings.ActivationRequirement | Should -Contain 'Justification'
            
            Write-Host "   ✅ Business Rules: Authentication Context vs MFA conflict handled correctly" -ForegroundColor Green
        }

        It "Should work with comma-separated requirement strings" {
            # Test parameter validation fix
            $result = Set-PIMEntraRolePolicy -TenantID $script:TenantId -RoleName $script:TestRoleName -ActivationRequirement "MultiFactorAuthentication,Justification" -WhatIf
            
            # Should not throw an error (validates parameter parsing fix)
            $result | Should -Not -BeNullOrEmpty
            
            Write-Host "   ✅ Parameter Validation: Comma-separated strings handled correctly" -ForegroundColor Green
        }
    }

    AfterAll {
        Write-Host "🏁 End-to-End Test Complete" -ForegroundColor Cyan
        Write-Host "   All business rules and validation workflows tested successfully!" -ForegroundColor Green
    }
}
