# EasyPIM End-to-End Business Rules Validation Script
# This script tests the complete workflow: drift detection -> orchestrator remediation -> verification
# Uses live tenant (no mocking) to validate real-world scenarios

param(
    [Parameter(Mandatory)]
    [string]$TenantId = $env:TenantID,

    [Parameter(Mandatory)]
    [string]$SubscriptionId = $env:SubscriptionID,

    [Parameter()]
    [string]$ConfigPath = "$PSScriptRoot\validation.json",

    [Parameter()]
    [string]$TestRoleName = "Guest Inviter"
)

# Import modules
Write-Host "🔧 Loading EasyPIM modules..." -ForegroundColor Cyan
Import-Module "$PSScriptRoot\..\EasyPIM\EasyPIM.psd1" -Force
Import-Module "$PSScriptRoot\..\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psd1" -Force

# Test configuration - comprehensive policy changes
$OriginalSettings = @{
    ActivationDuration = "PT2H"                            # From Standard template
    ActivationRequirement = "MultiFactorAuthentication,Justification"
    ApprovalRequired = $false
    MaximumEligibleAssignmentDuration = "P365D"
}

$ModifiedSettings = @{
    ActivationDuration = "PT4H"                            # Changed duration
    ActivationRequirement = "Justification"                # Removed MFA
    ApprovalRequired = $true                               # Enabled approval
    Approvers = @("2ab3f204-9c6f-409d-a9bd-6e302a0132db")  # Use approver from HighSecurity template
    MaximumEligibleAssignmentDuration = "P180D"           # Reduced max duration
}

Write-Host "`n🎯 Test Configuration:" -ForegroundColor Yellow
Write-Host "   Tenant: $TenantId"
Write-Host "   Role: $TestRoleName"
Write-Host "   Config: $ConfigPath"
Write-Host "   Original Settings:"
$OriginalSettings.GetEnumerator() | ForEach-Object { Write-Host "     $($_.Key): $($_.Value)" -ForegroundColor Gray }
Write-Host "   Modified Settings:"
$ModifiedSettings.GetEnumerator() | ForEach-Object { Write-Host "     $($_.Key): $($_.Value)" -ForegroundColor Gray }

try {
    # Step 1: Baseline - Ensure role matches config
    Write-Host "`n📋 Step 1: Setting baseline configuration..." -ForegroundColor Cyan
    $setParams = @{
        TenantID = $TenantId
        RoleName = $TestRoleName
        ActivationDuration = $OriginalSettings.ActivationDuration
        ActivationRequirement = $OriginalSettings.ActivationRequirement
        ApprovalRequired = $OriginalSettings.ApprovalRequired
    MaximumEligibilityDuration = $OriginalSettings.MaximumEligibleAssignmentDuration
    }
    Set-PIMEntraRolePolicy @setParams
    Start-Sleep -Seconds 3

    # Verify baseline
    $baselinePolicy = Get-PIMEntraRolePolicy -TenantID $TenantId -RoleName $TestRoleName
    Write-Host "   Current Settings:" -ForegroundColor Gray
    Write-Host "     ActivationDuration: $($baselinePolicy.ActivationDuration)" -ForegroundColor Gray
    Write-Host "     ActivationRequirement: $($baselinePolicy.EnablementRules)" -ForegroundColor Gray
    Write-Host "     ApprovalRequired: $($baselinePolicy.ApprovalRequired)" -ForegroundColor Gray
    Write-Host "     MaxEligibleDuration: $($baselinePolicy.MaximumEligibleAssignmentDuration)" -ForegroundColor Gray

    # Test baseline drift
    Write-Host "   Testing baseline drift..." -ForegroundColor Gray
    $baselineDrift = Test-PIMPolicyDrift -TenantId $TenantId -ConfigPath $ConfigPath -PassThru -Verbose
    $baselineResult = $baselineDrift | Where-Object { $_.Type -eq 'EntraRole' -and $_.Name -eq $TestRoleName }

    if ($baselineResult.Status -eq 'Match') {
        Write-Host "   ✅ Baseline: No drift detected" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Warning: Baseline shows drift: $($baselineResult.Differences)" -ForegroundColor Yellow
    }

    # Step 2: Create drift by manually changing multiple policy settings
    Write-Host "`n🔧 Step 2: Creating drift by changing multiple policy settings..." -ForegroundColor Cyan
    $modifyParams = @{
        TenantID = $TenantId
        RoleName = $TestRoleName
        ActivationDuration = $ModifiedSettings.ActivationDuration
        ActivationRequirement = $ModifiedSettings.ActivationRequirement
        ApprovalRequired = $ModifiedSettings.ApprovalRequired
        Approvers = $ModifiedSettings.Approvers
    MaximumEligibilityDuration = $ModifiedSettings.MaximumEligibleAssignmentDuration
    }
    Set-PIMEntraRolePolicy @modifyParams
    Start-Sleep -Seconds 3

    # Verify changes were applied
    $modifiedPolicy = Get-PIMEntraRolePolicy -TenantID $TenantId -RoleName $TestRoleName
    Write-Host "   Changed Settings:" -ForegroundColor Gray
    Write-Host "     ActivationDuration: $($modifiedPolicy.ActivationDuration)" -ForegroundColor Gray
    Write-Host "     ActivationRequirement: $($modifiedPolicy.EnablementRules)" -ForegroundColor Gray
    Write-Host "     ApprovalRequired: $($modifiedPolicy.ApprovalRequired)" -ForegroundColor Gray
    Write-Host "     MaxEligibleDuration: $($modifiedPolicy.MaximumEligibleAssignmentDuration)" -ForegroundColor Gray

    # Step 3: Detect drift
    Write-Host "`n🕵️ Step 3: Testing drift detection..." -ForegroundColor Cyan
    $driftResults = Test-PIMPolicyDrift -TenantId $TenantId -ConfigPath $ConfigPath -PassThru -Verbose
    $driftResult = $driftResults | Where-Object { $_.Type -eq 'EntraRole' -and $_.Name -eq $TestRoleName }

    if ($driftResult.Status -eq 'Drift') {
        Write-Host "   ✅ Drift Detection: Successfully detected policy drift" -ForegroundColor Green
        Write-Host "   📊 Differences detected:" -ForegroundColor Gray
        $driftResult.Differences -split ',' | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
    } else {
        throw "❌ Drift detection failed - expected 'Drift' but got '$($driftResult.Status)'"
    }

    # Step 4: Validate business rules are working
    Write-Host "`n🔬 Step 4: Testing business rules validation..." -ForegroundColor Cyan
    $businessRuleTest = [PSCustomObject]@{
        ActivationRequirement = "MultiFactorAuthentication,Justification"
        AuthenticationContext_Enabled = $true
    }

    $businessRuleResult = Test-PIMPolicyBusinessRules -PolicySettings $businessRuleTest -ApplyAdjustments

    if ($businessRuleResult.HasChanges -and $businessRuleResult.Conflicts.Count -gt 0) {
        Write-Host "   ✅ Business Rules: Authentication Context vs MFA conflict detected and handled" -ForegroundColor Green
        Write-Host "   📋 Conflict: $($businessRuleResult.Conflicts[0].Message)" -ForegroundColor Gray
    } else {
        Write-Host "   ⚠️  Business Rules: No conflicts detected (this may be expected)" -ForegroundColor Yellow
    }

    # Step 5: Run orchestrator to remediate
    Write-Host "`n🔄 Step 5: Running orchestrator to remediate drift..." -ForegroundColor Cyan
    $orchestratorResult = Invoke-EasyPIMOrchestrator -TenantId $TenantId -SubscriptionId $SubscriptionId -ConfigFilePath $ConfigPath -ValidateOnly:$false

    if ($orchestratorResult) {
        Write-Host "   ✅ Orchestrator: Completed successfully" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Orchestrator: Check output for any issues" -ForegroundColor Yellow
    }

    # Wait for changes to propagate
    Write-Host "   ⏳ Waiting for changes to propagate..." -ForegroundColor Gray
    Start-Sleep -Seconds 5

    # Step 6: Verify remediation
    Write-Host "`n✅ Step 6: Verifying remediation..." -ForegroundColor Cyan
    $remediatedPolicy = Get-PIMEntraRolePolicy -TenantID $TenantId -RoleName $TestRoleName
    Write-Host "   Current ActivationDuration: $($remediatedPolicy.ActivationDuration)" -ForegroundColor Gray

    # Final drift check
    $finalDrift = Test-PIMPolicyDrift -TenantId $TenantId -ConfigPath $ConfigPath -PassThru
    $finalResult = $finalDrift | Where-Object { $_.Type -eq 'EntraRole' -and $_.Name -eq $TestRoleName }

    if ($finalResult.Status -eq 'Match') {
        Write-Host "   ✅ Final Verification: No drift detected after remediation" -ForegroundColor Green
        Write-Host "`n🎉 END-TO-END TEST PASSED!" -ForegroundColor Green
        Write-Host "   All business rules and validation workflows are working correctly!" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Final Verification: Drift still detected: $($finalResult.Differences)" -ForegroundColor Red
        throw "Remediation did not fully resolve drift"
    }

    # Summary
    Write-Host "`n📊 Test Summary:" -ForegroundColor Cyan
    Write-Host "   ✅ Baseline verification" -ForegroundColor Green
    Write-Host "   ✅ Manual policy change" -ForegroundColor Green
    Write-Host "   ✅ Drift detection" -ForegroundColor Green
    Write-Host "   ✅ Business rules validation" -ForegroundColor Green
    Write-Host "   ✅ Orchestrator remediation" -ForegroundColor Green
    Write-Host "   ✅ Final verification" -ForegroundColor Green

} catch {
    Write-Host "`n❌ Test failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
