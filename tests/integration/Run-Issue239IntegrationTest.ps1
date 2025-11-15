<#
.SYNOPSIS
    Helper script to run Issue #239 integration test with real authentication

.DESCRIPTION
    This script handles authentication and runs the integration test for Issue #239
    to validate that MFA requirements are properly preserved during policy copy operations.

.PARAMETER RoleDisplayName
    The display name of a role to test with (must have MFA configured on active assignment)
    Default: "Security Reader"

.PARAMETER Scopes
    Microsoft Graph scopes to request during authentication
    Default: RoleManagement.Read.Directory (read-only, safe)

.EXAMPLE
    .\Run-Issue239IntegrationTest.ps1
    
.EXAMPLE
    .\Run-Issue239IntegrationTest.ps1 -RoleDisplayName "Global Reader"

.NOTES
    This test is READ-ONLY and safe to run - it only exports policies to temporary CSV files.
#>

param(
    [string]$RoleDisplayName = "Security Reader",
    [string[]]$Scopes = @("RoleManagement.Read.Directory")
)

Write-Host "🧪 Issue #239 Integration Test Runner" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if already authenticated
Write-Host "Step 1: Checking Microsoft Graph authentication..." -ForegroundColor Yellow
try {
    $context = Get-MgContext
    if ($context) {
        Write-Host "✅ Already authenticated as: $($context.Account)" -ForegroundColor Green
        Write-Host "   Tenant: $($context.TenantId)" -ForegroundColor Gray
        Write-Host "   Scopes: $($context.Scopes -join ', ')" -ForegroundColor Gray
    } else {
        throw "Not authenticated"
    }
} catch {
    Write-Host "⚠️  Not authenticated. Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Write-Host "   Required scopes: $($Scopes -join ', ')" -ForegroundColor Gray
    Write-Host ""
    
    try {
        Connect-MgGraph -Scopes $Scopes -NoWelcome
        $context = Get-MgContext
        Write-Host "✅ Successfully authenticated!" -ForegroundColor Green
        Write-Host "   Account: $($context.Account)" -ForegroundColor Gray
        Write-Host "   Tenant: $($context.TenantId)" -ForegroundColor Gray
    } catch {
        Write-Error "❌ Failed to authenticate: $_"
        Write-Host ""
        Write-Host "Please run manually:" -ForegroundColor Yellow
        Write-Host "  Connect-MgGraph -Scopes 'RoleManagement.Read.Directory'" -ForegroundColor White
        exit 1
    }
}

Write-Host ""

# Step 2: Verify role exists
Write-Host "Step 2: Verifying test role exists..." -ForegroundColor Yellow
Write-Host "   Looking for role: $RoleDisplayName" -ForegroundColor Gray

try {
    Import-Module "$PSScriptRoot\..\..\EasyPIM\EasyPIM.psd1" -Force
    
    # Try to get the role to verify it exists
    # Use Get-PIMEntraRole which uses Microsoft Graph API
    $roleCheck = Invoke-MgGraphRequest -Method GET `
                                      -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions" `
                                      -ErrorAction Stop
    
    $matchedRole = $roleCheck.value | Where-Object { $_.displayName -eq $RoleDisplayName }
    
    if ($matchedRole) {
        Write-Host "✅ Role found!" -ForegroundColor Green
        Write-Host "   Display Name: $($matchedRole.displayName)" -ForegroundColor Gray
        Write-Host "   Template ID: $($matchedRole.id)" -ForegroundColor Gray
    } else {
        throw "Role not found"
    }
} catch {
    Write-Error "❌ Role '$RoleDisplayName' not found in tenant"
    Write-Host ""
    Write-Host "Available roles in your tenant (first 15):" -ForegroundColor Yellow
    $allRoles = Invoke-MgGraphRequest -Method GET `
                                      -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions" `
                                      -ErrorAction SilentlyContinue
    if ($allRoles) {
        $allRoles.value | Select-Object -First 15 displayName | Format-Table
    }
    Write-Host ""
    Write-Host "Run with a different role:" -ForegroundColor Yellow
    Write-Host "  .\Run-Issue239IntegrationTest.ps1 -RoleDisplayName 'Your Role Name'" -ForegroundColor White
    exit 1
}

Write-Host ""

# Step 3: Run integration test
Write-Host "Step 3: Running integration test..." -ForegroundColor Yellow
Write-Host "   Test file: Copy-PIMEntraRolePolicy.MFA.Integration.Tests.ps1" -ForegroundColor Gray
Write-Host ""

# Update test config with custom role if specified
$testFile = Join-Path $PSScriptRoot "entra-roles\Copy-PIMEntraRolePolicy.MFA.Integration.Tests.ps1"

if (-not (Test-Path $testFile)) {
    Write-Error "❌ Test file not found: $testFile"
    exit 1
}

# Run the test
try {
    $pesterConfig = New-PesterConfiguration
    $pesterConfig.Run.Path = $testFile
    $pesterConfig.Run.PassThru = $true
    $pesterConfig.Output.Verbosity = 'Detailed'
    $pesterConfig.Should.ErrorAction = 'Continue'
    
    # Override the source role if custom one provided
    if ($RoleDisplayName -ne "Security Reader") {
        Write-Host "📝 Using custom role: $RoleDisplayName" -ForegroundColor Cyan
        # The test will pick this up from the testConfig in BeforeAll
        $env:EASYPIM_TEST_ROLE = $RoleDisplayName
    }
    
    $results = Invoke-Pester -Configuration $pesterConfig
    
    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host "📊 Test Results Summary" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Total Tests: $($results.TotalCount)" -ForegroundColor White
    Write-Host "Passed: $($results.PassedCount)" -ForegroundColor Green
    Write-Host "Failed: $($results.FailedCount)" -ForegroundColor $(if ($results.FailedCount -gt 0) { "Red" } else { "Green" })
    Write-Host "Skipped: $($results.SkippedCount)" -ForegroundColor Yellow
    Write-Host ""
    
    if ($results.FailedCount -eq 0) {
        Write-Host "✅ Issue #239 VALIDATED - MFA preservation works correctly!" -ForegroundColor Green
        Write-Host ""
        Write-Host "The fix is working:" -ForegroundColor Green
        Write-Host "  ✅ MFA requirements are preserved during export" -ForegroundColor Green
        Write-Host "  ✅ MFA survives CSV round-trip" -ForegroundColor Green
        Write-Host "  ✅ MFA is correctly included in API payload" -ForegroundColor Green
        Write-Host "  ✅ Ticketing is correctly filtered out (Rule #7 spec)" -ForegroundColor Green
    } else {
        Write-Host "❌ Test failures detected - review output above" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Error "❌ Test execution failed: $_"
    exit 1
}

Write-Host ""
Write-Host "Test completed successfully!" -ForegroundColor Green
