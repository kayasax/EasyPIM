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

# Step 2: Pick an existing Entra (directory) role from a safe list
Write-Host "Step 2: Locating a safe Entra role (Security Reader, Global Reader, Directory Readers, Reports Reader)..." -ForegroundColor Yellow

$preferredRoles = @(
    'Security Reader'
    'Global Reader'
    'Directory Readers'
    'Reports Reader'
)

try {
    $allRoles = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions" -ErrorAction Stop).value
} catch {
    Write-Error "❌ Failed to query directory role definitions: $_"
    exit 1
}

$selectedRole = $null
foreach ($r in $preferredRoles) {
    $match = $allRoles | Where-Object { $_.displayName -eq $r }
    if ($match) { $selectedRole = $match; break }
}

if (-not $selectedRole) {
    Write-Error "❌ No preferred Entra role found in tenant. Available roles (sample):"
    $allRoles | Select-Object -First 10 -Property displayName,id | Format-Table
    exit 1
}

Write-Host "✅ Selected Entra role: $($selectedRole.displayName) ($($selectedRole.id))" -ForegroundColor Green
Write-Host ""

# Step 3: Get current policy
Write-Host "Step 3: Getting current AcrPull policy..." -ForegroundColor Yellow
try {
    $roleName = $selectedRole.displayName
    $currentConfig = Get-PIMEntraRolePolicy -tenantID $tenantId -rolename $roleName
    Write-Host "✅ Current policy retrieved for role '$roleName'" -ForegroundColor Green
    Write-Host "   Current ActiveAssignmentRequirement: $($currentConfig.rules | Where-Object id -eq 'Enablement_Admin_Assignment' | Select-Object -ExpandProperty enabledRules)" -ForegroundColor Gray
} catch {
    Write-Error "❌ Failed to get current policy for role '$roleName': $_"
    exit 1
}

Write-Host ""

# Step 4: Configure MFA on active assignment
Write-Host "Step 4: Configuring MFA on selected Entra role active assignment (Rule #7)..." -ForegroundColor Yellow
Write-Host "   Adding: MultiFactorAuthentication + Justification to role '$roleName'" -ForegroundColor Gray

try {
    # Use Set-PIMEntraRolePolicy to update the policy
    Set-PIMEntraRolePolicy -tenantID $tenantId `
                          -rolename $roleName `
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
Write-Host "Step 5: Verifying configuration (polling for propagation)..." -ForegroundColor Yellow

# Wait up to 60s for the MFA requirement to appear (poll every 5s)
$ok = $false
try {
    $ok = Wait-ForPolicyRule -TenantId $tenantId -RoleName $roleName -RuleId 'Enablement_Admin_Assignment' -ExpectedValue 'MultiFactorAuthentication' -TimeoutSeconds 60 -IntervalSeconds 5
} catch {
    Write-Warning "Verification helper failed: $_"
}

if ($ok) {
    $verifyConfig = Get-PIMEntraRolePolicy -tenantID $tenantId -rolename $roleName
    $activeRule = $verifyConfig.rules | Where-Object id -eq 'Enablement_Admin_Assignment'
    Write-Host "✅ MFA successfully configured and observed after propagation!" -ForegroundColor Green
    Write-Host "   ActiveAssignmentRequirement: $($activeRule.enabledRules -join ', ')" -ForegroundColor Gray
} else {
    Write-Warning "⚠️  MFA not detected after polling. This may take longer to propagate or the update did not apply correctly."
    try {
        $verifyConfig = Get-PIMEntraRolePolicy -tenantID $tenantId -rolename $roleName
        $activeRule = $verifyConfig.rules | Where-Object id -eq 'Enablement_Admin_Assignment'
        Write-Host "   Current value: $($activeRule.enabledRules -join ', ')" -ForegroundColor Gray
    } catch { }
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
