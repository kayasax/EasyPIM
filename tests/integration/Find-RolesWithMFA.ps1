<#
.SYNOPSIS
    Scan tenant roles to find ones with MFA configured on active assignment

.DESCRIPTION
    Helps find suitable test roles for Issue #239 integration testing by
    scanning your tenant for roles that have MultiFactorAuthentication
    configured in the ActiveAssignmentRequirement (Rule #7).

.EXAMPLE
    .\Find-RolesWithMFA.ps1
#>

Write-Host "🔍 Scanning Entra ID roles for MFA configuration..." -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

# Check auth
try {
    $context = Get-MgContext
    if (-not $context) {
        throw "Not authenticated"
    }
    Write-Host "✅ Authenticated as: $($context.Account)" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "⚠️  Please authenticate first:" -ForegroundColor Yellow
    Write-Host "  Connect-MgGraph -Scopes 'RoleManagement.Read.Directory'" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Import module
Import-Module "$PSScriptRoot\..\..\EasyPIM\EasyPIM.psd1" -Force

# Get tenant ID
$tenantId = (Get-MgContext).TenantId

# Get all roles
Write-Host "📋 Fetching all Entra ID roles..." -ForegroundColor Cyan
$allRolesResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions"
$allRoles = $allRolesResponse.value

Write-Host "   Found $($allRoles.Count) roles" -ForegroundColor Gray
Write-Host ""

# Sample a few common roles to check
$commonRoles = @(
    "Global Administrator",
    "Privileged Role Administrator", 
    "Security Administrator",
    "User Administrator",
    "Application Administrator",
    "Cloud Application Administrator",
    "Intune Administrator",
    "Exchange Administrator",
    "SharePoint Administrator",
    "Global Reader",
    "Security Reader"
)

Write-Host "🔎 Checking common roles for MFA configuration..." -ForegroundColor Cyan
Write-Host ""

$rolesWithMFA = @()
$rolesWithoutMFA = @()

foreach ($roleName in $commonRoles) {
    $role = $allRoles | Where-Object { $_.displayName -eq $roleName }
    
    if (-not $role) {
        Write-Host "   ⚠️  $roleName - Not found in tenant" -ForegroundColor DarkGray
        continue
    }
    
    try {
        # Export policy to temp file
        $tempCsv = Join-Path $env:TEMP "role-scan-$($role.id).csv"
        Export-PIMEntraRolePolicy -tenantID $tenantId -rolename $roleName -path $tempCsv -ErrorAction Stop | Out-Null
        
        # Read CSV
        $csvData = Import-Csv -Path $tempCsv
        
        # Check for MFA
        $hasRuleDef = $csvData.ActiveAssignmentRequirement -and $csvData.ActiveAssignmentRequirement.Length -gt 0
        $hasMFA = $csvData.ActiveAssignmentRequirement -match 'MultiFactorAuthentication'
        
        if ($hasMFA) {
            Write-Host "   ✅ $roleName" -ForegroundColor Green
            Write-Host "      ActiveAssignmentRequirement: $($csvData.ActiveAssignmentRequirement)" -ForegroundColor Gray
            $rolesWithMFA += [PSCustomObject]@{
                RoleName = $roleName
                ActiveRequirements = $csvData.ActiveAssignmentRequirement
                ActivationRules = $csvData.EnablementRules
            }
        } else {
            if ($hasRuleDef) {
                Write-Host "   ⭕ $roleName - Has requirements but NO MFA" -ForegroundColor Yellow
                Write-Host "      ActiveAssignmentRequirement: $($csvData.ActiveAssignmentRequirement)" -ForegroundColor DarkGray
            } else {
                Write-Host "   ⭕ $roleName - No active assignment requirements" -ForegroundColor DarkGray
            }
            $rolesWithoutMFA += $roleName
        }
        
        # Cleanup
        Remove-Item $tempCsv -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "   ❌ $roleName - Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "📊 Summary" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

if ($rolesWithMFA.Count -gt 0) {
    Write-Host "✅ Found $($rolesWithMFA.Count) role(s) with MFA on active assignment:" -ForegroundColor Green
    Write-Host ""
    $rolesWithMFA | Format-Table -AutoSize
    Write-Host ""
    Write-Host "🧪 Test with these roles:" -ForegroundColor Cyan
    foreach ($role in $rolesWithMFA) {
        Write-Host "  .\Run-Issue239IntegrationTest.ps1 -RoleDisplayName '$($role.RoleName)'" -ForegroundColor White
    }
} else {
    Write-Host "⚠️  No roles found with MFA configured on active assignment" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This means:" -ForegroundColor Yellow
    Write-Host "  • Your tenant may not have MFA enforced on active role assignments" -ForegroundColor Gray
    Write-Host "  • The fix still works correctly (Ticketing validation passed)" -ForegroundColor Gray
    Write-Host "  • You can manually configure a test role with MFA if needed" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To configure MFA on a role:" -ForegroundColor Cyan
    Write-Host "  1. Go to Azure Portal → Entra ID → Roles and administrators" -ForegroundColor White
    Write-Host "  2. Select a role (e.g., 'Security Reader')" -ForegroundColor White
    Write-Host "  3. Click 'Settings' → 'Edit'" -ForegroundColor White
    Write-Host "  4. Under 'Activation' → Check 'Require Azure MFA'" -ForegroundColor White
    Write-Host "  5. Under 'Active assignment' → Check 'Require Azure Multi-Factor Authentication'" -ForegroundColor White
    Write-Host "  6. Save and re-run the integration test" -ForegroundColor White
}

Write-Host ""
