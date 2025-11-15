<#
.SYNOPSIS
    Complete end-to-end test for Issue #239 with real role configuration

.DESCRIPTION
    This script:
    1. Configures AcrPull role with MFA on active assignment
    2. Exports AcrPull policy to CSV
    3. Copies policy from AcrPull to AcrPush
    4. Validates MFA is preserved in AcrPush
    5. Cleans up by reverting both roles

.PARAMETER SkipSetup
    Skip the initial role configuration (assumes AcrPull already has MFA)

.PARAMETER SkipCleanup
    Keep the MFA configuration after test completes

.EXAMPLE
    .\Test-Issue239-E2E.ps1

.EXAMPLE
    .\Test-Issue239-E2E.ps1 -SkipSetup -SkipCleanup

.NOTES
    Requires: RoleManagement.ReadWrite.Directory scope
    Uses: AcrPull and AcrPush roles (non-critical, safe for testing)
#>

param(
    [switch]$SkipSetup,
    [switch]$SkipCleanup
)

Write-Host "🧪 Issue #239 End-to-End Integration Test" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""
Write-Host "This test will:" -ForegroundColor Yellow
Write-Host "  1. Configure 'Directory Readers' with MFA on active assignment (Rule #7)" -ForegroundColor White
Write-Host "  2. Export 'Directory Readers' policy to CSV" -ForegroundColor White
Write-Host "  3. Copy policy from 'Directory Readers' → 'Reports Reader' using Copy-PIMEntraRolePolicy" -ForegroundColor White
Write-Host "  4. Validate MFA is preserved in 'Reports Reader'" -ForegroundColor White
Write-Host "  5. Clean up (revert configurations)" -ForegroundColor White
Write-Host ""
Write-Host "Note: Using non-critical Entra ID roles safe for testing" -ForegroundColor Gray
Write-Host ""

# Role names
$sourceRole = "Directory Readers"
$targetRole = "Reports Reader"

# Authentication
Write-Host "🔐 Checking authentication..." -ForegroundColor Cyan
try {
    $context = Get-MgContext
    if (-not $context -or $context.Scopes -notcontains "RoleManagement.ReadWrite.Directory") {
        Write-Host "   Connecting with required scope..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory" -NoWelcome
        $context = Get-MgContext
    }
    Write-Host "✅ Authenticated as: $($context.Account)" -ForegroundColor Green
} catch {
    Write-Error "❌ Authentication failed"
    exit 1
}

# Import module
Import-Module "$PSScriptRoot\..\..\EasyPIM\EasyPIM.psd1" -Force
$tenantId = $context.TenantId

Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "PHASE 1: Setup Source Role ($sourceRole)" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

if (-not $SkipSetup) {
    Write-Host "📝 Backing up original $sourceRole configuration..." -ForegroundColor Yellow
    $originalAcrPull = Get-PIMEntraRolePolicy -tenantID $tenantId -rolename $sourceRole
    $originalAcrPullActive = $originalAcrPull.rules | Where-Object id -eq 'Enablement_Admin_Assignment' | Select-Object -ExpandProperty enabledRules
    Write-Host "   Original: $($originalAcrPullActive -join ', ')" -ForegroundColor Gray
    
    Write-Host "🔧 Configuring $sourceRole with MFA + Justification..." -ForegroundColor Yellow
    Set-PIMEntraRolePolicy -tenantID $tenantId `
                          -rolename $sourceRole `
                          -ActiveAssignmentRequirement "MultiFactorAuthentication", "Justification"
    
    Write-Host "⏳ Waiting for Azure propagation (10 seconds)..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
    
    $verifyAcrPull = Get-PIMEntraRolePolicy -tenantID $tenantId -rolename $sourceRole
    $verifyAcrPullActive = $verifyAcrPull.rules | Where-Object id -eq 'Enablement_Admin_Assignment' | Select-Object -ExpandProperty enabledRules
    
    Write-Host "   Verification result: $($verifyAcrPullActive -join ', ')" -ForegroundColor Gray
    
    if ($verifyAcrPullActive -contains 'MultiFactorAuthentication') {
        Write-Host "✅ $sourceRole configured: $($verifyAcrPullActive -join ', ')" -ForegroundColor Green
    } else {
        Write-Warning "⚠️  MFA not immediately visible (Azure propagation delay)"
        Write-Host "   Continuing with test - export will show actual state" -ForegroundColor Yellow
    }
} else {
    Write-Host "⏭️  Skipping setup (using existing $sourceRole configuration)" -ForegroundColor Yellow
    $verifyAcrPull = Get-PIMEntraRolePolicy -tenantID $tenantId -rolename $sourceRole
    $verifyAcrPullActive = $verifyAcrPull.rules | Where-Object id -eq 'Enablement_Admin_Assignment' | Select-Object -ExpandProperty enabledRules
    Write-Host "   Current AcrPull: $($verifyAcrPullActive -join ', ')" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "PHASE 2: Export Source Policy" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

$exportPath = Join-Path $env:TEMP "issue239-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
Write-Host "📤 Exporting $sourceRole policy to CSV..." -ForegroundColor Yellow
Write-Host "   Path: $exportPath" -ForegroundColor Gray

Export-PIMEntraRolePolicy -tenantID $tenantId -rolename $sourceRole -path $exportPath

$exportedCsv = Import-Csv -Path $exportPath
Write-Host "✅ Export completed" -ForegroundColor Green
Write-Host "   ActiveAssignmentRequirement: $($exportedCsv.ActiveAssignmentRequirement)" -ForegroundColor Gray
Write-Host "   EnablementRules: $($exportedCsv.EnablementRules)" -ForegroundColor Gray

# Validate CSV has MFA
if ($exportedCsv.ActiveAssignmentRequirement -match 'MultiFactorAuthentication') {
    Write-Host "✅ TEST PASSED: MFA present in exported CSV" -ForegroundColor Green
} else {
    Write-Error "❌ TEST FAILED: MFA missing from exported CSV"
    exit 1
}

# Validate CSV does NOT have Ticketing (Issue #239 secondary fix)
if ($exportedCsv.ActiveAssignmentRequirement -match 'Ticketing') {
    Write-Error "❌ TEST FAILED: Ticketing incorrectly present in ActiveAssignmentRequirement (Rule #7 violation)"
    exit 1
} else {
    Write-Host "✅ TEST PASSED: Ticketing correctly filtered out (Rule #7 spec compliant)" -ForegroundColor Green
}

Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "PHASE 3: Copy Policy to Target Role ($targetRole)" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

Write-Host "📝 Backing up original $targetRole configuration..." -ForegroundColor Yellow
$originalAcrPush = Get-PIMEntraRolePolicy -tenantID $tenantId -rolename $targetRole
$originalAcrPushActive = $originalAcrPush.rules | Where-Object id -eq 'Enablement_Admin_Assignment' | Select-Object -ExpandProperty enabledRules
Write-Host "   Original: $($originalAcrPushActive -join ', ')" -ForegroundColor Gray

Write-Host "🔄 Copying policy: $sourceRole → $targetRole..." -ForegroundColor Yellow
Copy-PIMEntraRolePolicy -tenantID $tenantId -rolename $targetRole -copyFrom $sourceRole

Write-Host "⏳ Waiting for Azure propagation (15 seconds)..." -ForegroundColor Gray
Start-Sleep -Seconds 15

Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "PHASE 4: Validate Target Role" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

Write-Host "🔍 Checking $targetRole configuration..." -ForegroundColor Yellow
$verifyAcrPush = Get-PIMEntraRolePolicy -tenantID $tenantId -rolename $targetRole
$verifyAcrPushActive = $verifyAcrPush.rules | Where-Object id -eq 'Enablement_Admin_Assignment' | Select-Object -ExpandProperty enabledRules

Write-Host "   $targetRole ActiveAssignmentRequirement: $($verifyAcrPushActive -join ', ')" -ForegroundColor Gray

# CRITICAL TEST: Does target role have MFA?
if ($verifyAcrPushActive -contains 'MultiFactorAuthentication') {
    Write-Host "✅ TEST PASSED: MFA preserved in $targetRole after copy!" -ForegroundColor Green
} else {
    Write-Warning "⚠️  MFA not immediately visible in $targetRole (Azure propagation delay)"
    Write-Host "   Expected: MultiFactorAuthentication" -ForegroundColor Yellow
    Write-Host "   Actual: $($verifyAcrPushActive -join ', ')" -ForegroundColor Yellow
    Write-Host "   Let's verify with fresh export..." -ForegroundColor Yellow
    
    # Export target role to CSV to see actual state
    $verifyExport = Join-Path $env:TEMP ("verify-$targetRole-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Export-PIMEntraRolePolicy -tenantID $tenantId -rolename $targetRole -path $verifyExport -ErrorAction Stop | Out-Null
    $verifyData = Import-Csv $verifyExport
    
    Write-Host "   Export shows ActiveAssignmentRequirement: $($verifyData.ActiveAssignmentRequirement)" -ForegroundColor Cyan
    
    if ($verifyData.ActiveAssignmentRequirement -match 'MultiFactorAuthentication') {
        Write-Host "✅ TEST PASSED: MFA confirmed in $targetRole via export!" -ForegroundColor Green
        Remove-Item $verifyExport -Force -ErrorAction SilentlyContinue
    } else {
        Write-Error "❌ TEST FAILED: MFA NOT preserved in $targetRole (even in export)"
        Write-Host "   CSV ActiveAssignmentRequirement: $($verifyData.ActiveAssignmentRequirement)" -ForegroundColor Red
        exit 1
    }
}

# Validate no Ticketing leaked through (check both direct query and export)
$hasTicketing = $false
if ($verifyAcrPushActive -contains 'Ticketing') {
    $hasTicketing = $true
} elseif ($verifyData -and $verifyData.ActiveAssignmentRequirement -match 'Ticketing') {
    $hasTicketing = $true
}

if ($hasTicketing) {
    Write-Error "❌ TEST FAILED: Ticketing incorrectly present in $targetRole (Rule #7 violation)"
    exit 1
} else {
    Write-Host "✅ TEST PASSED: No Ticketing in $targetRole (Rule #7 spec compliant)" -ForegroundColor Green
}

Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "PHASE 5: Cleanup" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

if (-not $SkipCleanup) {
    Write-Host "🧹 Reverting roles to original configuration..." -ForegroundColor Yellow
    
    # Revert source role
    if ($originalAcrPullActive -and $originalAcrPullActive.Count -gt 0) {
        Write-Host "   Reverting $sourceRole to: $($originalAcrPullActive -join ', ')" -ForegroundColor Gray
        Set-PIMEntraRolePolicy -tenantID $tenantId `
                              -rolename $sourceRole `
                              -ActiveAssignmentRequirement $originalAcrPullActive
    } else {
        Write-Host "   $sourceRole had no active assignment requirements originally" -ForegroundColor Gray
    }
    
    # Revert target role
    if ($originalAcrPushActive -and $originalAcrPushActive.Count -gt 0) {
        Write-Host "   Reverting $targetRole to: $($originalAcrPushActive -join ', ')" -ForegroundColor Gray
        Set-PIMEntraRolePolicy -tenantID $tenantId `
                              -rolename $targetRole `
                              -ActiveAssignmentRequirement $originalAcrPushActive
    } else {
        Write-Host "   $targetRole had no active assignment requirements originally" -ForegroundColor Gray
    }
    
    Write-Host "✅ Cleanup completed" -ForegroundColor Green
} else {
    Write-Host "⏭️  Skipping cleanup (keeping MFA configuration)" -ForegroundColor Yellow
}

# Clean up temp CSV
if (Test-Path $exportPath) {
    Remove-Item $exportPath -Force
}

Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "🎉 ISSUE #239 - ALL TESTS PASSED!" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Export preserved MFA in CSV" -ForegroundColor Green
Write-Host "✅ Copy operation preserved MFA in target role" -ForegroundColor Green
Write-Host "✅ Ticketing correctly filtered out (Rule #7 compliant)" -ForegroundColor Green
Write-Host "✅ Complete workflow validated with REAL Azure tenant data" -ForegroundColor Green
Write-Host ""
Write-Host "The Issue #239 fix is confirmed working!" -ForegroundColor Green
Write-Host ""
