<#
.SYNOPSIS
    Configure a test role with MFA for Issue #239 integration testing

.DESCRIPTION
    Sets up AcrPull role with MFA on active assignment requirement,
    then tests copying to AcrPush role to validate Issue #239 fix.
    
    These are non-critical Azure RBAC roles safe for testing.

.EXAMPLE
    .\Setup-Issue239TestRole.ps1

.NOTES
    Requires: RoleManagement.ReadWrite.Directory scope
#>

Write-Host "🔧 Issue #239 Test Role Setup" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

# Check authentication
Write-Host "Step 1: Checking Microsoft Graph authentication..." -ForegroundColor Yellow
try {
    $context = Get-MgContext
    if ($context) {
        Write-Host "✅ Authenticated as: $($context.Account)" -ForegroundColor Green
        
        # Check if we have write permissions
        if ($context.Scopes -notcontains "RoleManagement.ReadWrite.Directory") {
            Write-Warning "⚠️  Missing required scope: RoleManagement.ReadWrite.Directory"
            Write-Host ""
            Write-Host "Reconnecting with required scope..." -ForegroundColor Yellow
            Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory" -NoWelcome
            $context = Get-MgContext
        }
    } else {
        throw "Not authenticated"
    }
} catch {
    Write-Host "⚠️  Connecting to Microsoft Graph with write permissions..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory" -NoWelcome
    $context = Get-MgContext
}

Write-Host ""

# Import EasyPIM
Import-Module "$PSScriptRoot\..\..\EasyPIM\EasyPIM.psd1" -Force

# Get tenant ID
$tenantId = $context.TenantId
Write-Host "📋 Tenant ID: $tenantId" -ForegroundColor Gray
Write-Host ""

# Step 2: Find the AcrPull role (safer, non-critical role)
Write-Host "Step 2: Finding 'AcrPull' role..." -ForegroundColor Yellow
$acrPullRole = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions" |
    Select-Object -ExpandProperty value |
    Where-Object { $_.displayName -eq "AcrPull" }

if (-not $acrPullRole) {
    Write-Error "❌ AcrPull role not found in tenant"
    Write-Host ""
    Write-Host "Alternative test roles you can use:" -ForegroundColor Yellow
    Write-Host "  • Security Reader" -ForegroundColor White
    Write-Host "  • Directory Readers" -ForegroundColor White
    Write-Host "  • Reports Reader" -ForegroundColor White
    exit 1
}

Write-Host "✅ Found: $($acrPullRole.displayName) ($($acrPullRole.id))" -ForegroundColor Green
Write-Host ""

# Step 3: Get current policy
Write-Host "Step 3: Getting current AcrPull policy..." -ForegroundColor Yellow
try {
    $currentConfig = Get-PIMEntraRolePolicy -tenantID $tenantId -rolename "AcrPull"
    Write-Host "✅ Current policy retrieved" -ForegroundColor Green
    Write-Host "   Current ActiveAssignmentRequirement: $($currentConfig.rules | Where-Object id -eq 'Enablement_Admin_Assignment' | Select-Object -ExpandProperty enabledRules)" -ForegroundColor Gray
} catch {
    Write-Error "❌ Failed to get current policy: $_"
    exit 1
}

Write-Host ""

# Step 4: Configure MFA on active assignment
Write-Host "Step 4: Configuring MFA on AcrPull active assignment (Rule #7)..." -ForegroundColor Yellow
Write-Host "   Adding: MultiFactorAuthentication + Justification" -ForegroundColor Gray

try {
    # Use Set-PIMEntraRolePolicy to update the policy
    Set-PIMEntraRolePolicy -tenantID $tenantId `
                          -rolename "AcrPull" `
                          -ActiveAssignmentRequirement "MultiFactorAuthentication", "Justification" `
                          -Verbose
    
    Write-Host "✅ Policy updated successfully!" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to update policy: $_"
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Ensure you have Privileged Role Administrator or Global Administrator role" -ForegroundColor White
    Write-Host "  2. Check that RoleManagement.ReadWrite.Directory scope is granted" -ForegroundColor White
    Write-Host "  3. Verify no Conditional Access policies blocking the change" -ForegroundColor White
    exit 1
}

Write-Host ""

# Step 5: Verify the change
Write-Host "Step 5: Verifying configuration..." -ForegroundColor Yellow
Start-Sleep -Seconds 2  # Wait for Azure to propagate changes

$verifyConfig = Get-PIMEntraRolePolicy -tenantID $tenantId -rolename "AcrPull"
$activeRule = $verifyConfig.rules | Where-Object id -eq 'Enablement_Admin_Assignment'

if ($activeRule.enabledRules -contains 'MultiFactorAuthentication') {
    Write-Host "✅ MFA successfully configured!" -ForegroundColor Green
    Write-Host "   ActiveAssignmentRequirement: $($activeRule.enabledRules -join ', ')" -ForegroundColor Gray
} else {
    Write-Warning "⚠️  MFA not detected in configuration. This may take a few moments to propagate."
    Write-Host "   Current value: $($activeRule.enabledRules -join ', ')" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "✅ Setup Complete!" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Wait 30 seconds for Azure to propagate changes" -ForegroundColor White
Write-Host "  2. Run the integration test:" -ForegroundColor White
Write-Host "     .\Run-Issue239IntegrationTest.ps1 -RoleDisplayName 'AcrPull'" -ForegroundColor Yellow
Write-Host ""
Write-Host "  3. Test copying to AcrPush:" -ForegroundColor White
Write-Host "     Copy-PIMEntraRolePolicy -tenantID '$tenantId' -sourceRoleName 'AcrPull' -targetRoleName 'AcrPush'" -ForegroundColor Yellow
Write-Host ""
Write-Host "  4. Verify AcrPush received MFA:" -ForegroundColor White
Write-Host "     Get-PIMEntraRolePolicy -tenantID '$tenantId' -rolename 'AcrPush'" -ForegroundColor Yellow
Write-Host ""
