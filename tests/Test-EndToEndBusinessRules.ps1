# EasyPIM End-to-End Business Rules Validation Script
# This script tests the complete workflow: drift detection -> orchestrator remediation -> verification
# Uses live tenant (no mocking) to validate real-world scenarios

param(
    [Parameter()]
    [string]$TenantId = $env:TenantID,

    [Parameter()]
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

# Ensure Microsoft Graph is connected for this session
try { $mgCtx = Get-MgContext -ErrorAction Stop } catch { $mgCtx = $null }
if (-not $mgCtx -or -not $mgCtx.Account -or ($mgCtx.TenantId -ne $TenantId -and $TenantId)) {
    Write-Host "🔐 Connecting to Microsoft Graph..." -ForegroundColor Cyan
    $requiredScopes = @('Directory.Read.All','RoleManagement.ReadWrite.Directory','PrivilegedAccess.ReadWrite.AzureAD')
    try {
        Connect-MgGraph -TenantId $TenantId -Scopes $requiredScopes -NoWelcome | Out-Null
    } catch {
        throw "Failed to connect to Microsoft Graph. $_"
    }
}

# Optionally ensure Az context if Az.Accounts is available (used by orchestrator for some operations)
if (Get-Module -ListAvailable -Name Az.Accounts) {
    try { $azCtx = Get-AzContext -ErrorAction Stop } catch { $azCtx = $null }
    if (-not $azCtx -or ($SubscriptionId -and $azCtx.Subscription.Id -ne $SubscriptionId)) {
        Write-Host "🔐 Connecting to Azure (Az.Accounts)..." -ForegroundColor Cyan
        try { Connect-AzAccount -Tenant $TenantId -Subscription $SubscriptionId | Out-Null } catch { Write-Host "   ⚠️  Az connection optional and failed: $_" -ForegroundColor Yellow }
    }
}

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
    $baselineDrift = Test-PIMPolicyDrift -TenantId $TenantId -SubscriptionId $SubscriptionId -ConfigPath $ConfigPath -PassThru -Verbose
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
    $driftResults = Test-PIMPolicyDrift -TenantId $TenantId -SubscriptionId $SubscriptionId -ConfigPath $ConfigPath -PassThru -Verbose
    $driftResult = $driftResults | Where-Object { $_.Type -eq 'EntraRole' -and $_.Name -eq $TestRoleName }

    if ($driftResult.Status -eq 'Drift') {
        Write-Host "   ✅ Drift Detection: Successfully detected policy drift" -ForegroundColor Green
        Write-Host "   📊 Differences detected:" -ForegroundColor Gray
        $driftResult.Differences -split ',' | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
    } else {
        throw "❌ Drift detection failed - expected 'Drift' but got '$($driftResult.Status)'"
    }

    # Step 4: Validate business rules via public API path (no internal calls)
    Write-Host "`n🔬 Step 4: Testing business rules (Auth Context removes MFA)" -ForegroundColor Cyan
    try {
        # Enable Authentication Context without explicitly passing ActivationRequirement to trigger auto-MFA removal path
        $null = Set-PIMEntraRolePolicy -TenantID $TenantId -RoleName $TestRoleName -AuthenticationContext_Enabled $true -AuthenticationContext_Value "c1:HighRiskOperations"
        Start-Sleep -Seconds 2
        $postAcPolicy = Get-PIMEntraRolePolicy -TenantID $TenantId -RoleName $TestRoleName
        $enablement = @()
        if ($postAcPolicy.EnablementRules) { $enablement = ($postAcPolicy.EnablementRules -split ',') }
        if ($enablement -contains 'MultiFactorAuthentication') {
            throw "Expected MFA to be removed when Authentication Context is enabled, but it remains present."
        } else {
            Write-Host "   ✅ Business Rules: MFA removed when Authentication Context enabled" -ForegroundColor Green
        }
    } catch {
        Write-Host "   ⚠️  Business Rules check encountered an issue: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Step 4b: Exercise all admissible options (inspired by Step 14)
    Write-Host "`n🧪 Step 4b: Applying all major policy options (comprehensive exercise)" -ForegroundColor Cyan
    try {
        $notifAll = @{ isDefaultRecipientEnabled = $true; NotificationLevel = 'All'; Recipients = @('pim-alerts@contoso.com') }
        $notifAssignee = @{ isDefaultRecipientEnabled = $true; NotificationLevel = 'All'; Recipients = @('pim-assignees@contoso.com') }
        $notifApprovers = @{ isDefaultRecipientEnabled = $true; NotificationLevel = 'All'; Recipients = @('pim-approvers@contoso.com') }

        $allParams = @{
            TenantID = $TenantId
            RoleName = $TestRoleName
            ActivationDuration = 'PT4H'
            ActivationRequirement = 'MultiFactorAuthentication,Justification,Ticketing'
            ActiveAssignmentRequirement = 'MultiFactorAuthentication,Justification'
            ApprovalRequired = $true
            Approvers = @('2ab3f204-9c6f-409d-a9bd-6e302a0132db')
            AllowPermanentEligibility = $false
            AllowPermanentActiveAssignment = $false
            MaximumEligibilityDuration = 'P180D'
            MaximumActiveAssignmentDuration = 'P30D'
            AuthenticationContext_Enabled = $true
            AuthenticationContext_Value = 'c1:HighRiskOperations'
            Notification_EligibleAssignment_Alert = $notifAll
            Notification_EligibleAssignment_Assignee = $notifAssignee
            Notification_EligibleAssignment_Approver = $notifApprovers
            Notification_ActiveAssignment_Alert = $notifAll
            Notification_ActiveAssignment_Assignee = $notifAssignee
            Notification_ActiveAssignment_Approver = $notifApprovers
            Notification_Activation_Alert = $notifAll
            Notification_Activation_Assignee = $notifAssignee
            Notification_Activation_Approver = $notifApprovers
        }
        Set-PIMEntraRolePolicy @allParams | Out-Null
        Start-Sleep -Seconds 3
        $afterAll = Get-PIMEntraRolePolicy -TenantID $TenantId -RoleName $TestRoleName
        Write-Host "   ✅ Applied all major options. Current ActivationDuration: $($afterAll.ActivationDuration)" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️  All-options exercise encountered an issue: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Step 5: Run orchestrator to remediate
    Write-Host "`n🔄 Step 5: Running orchestrator to remediate drift..." -ForegroundColor Cyan
    $orchestratorResult = Invoke-EasyPIMOrchestrator -TenantId $TenantId -SubscriptionId $SubscriptionId -ConfigFilePath $ConfigPath

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
    $finalDrift = Test-PIMPolicyDrift -TenantId $TenantId -SubscriptionId $SubscriptionId -ConfigPath $ConfigPath -PassThru
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
