#!/usr/bin/env pwsh
# Diagnostic script to check User Administrator policy values

try {
    Write-Host "🔍 Checking User Administrator role policy..." -ForegroundColor Cyan

    # Import the EasyPIM module
    Import-Module "d:\WIP\EASYPIM\EasyPIM" -Force

    $tenantID = $env:TENANTID
    if (!$tenantID) {
        Write-Host "❌ TENANTID environment variable not set" -ForegroundColor Red
        exit 1
    }

    $policy = Get-PIMEntraRolePolicy -tenantID $tenantID -rolename "User Administrator"

    Write-Host "`n📊 User Administrator Policy Values:" -ForegroundColor Yellow
    Write-Host "  ActivationDuration: '$($policy.ActivationDuration)'" -ForegroundColor Green
    Write-Host "  MaximumActiveAssignmentDuration: '$($policy.MaximumActiveAssignmentDuration)'" -ForegroundColor Green
    Write-Host "  AllowPermanentActiveAssignment: '$($policy.AllowPermanentActiveAssignment)'" -ForegroundColor Green
    Write-Host "  ApprovalRequired: '$($policy.ApprovalRequired)'" -ForegroundColor Green

    # Check for potential issues
    Write-Host "`n🔍 Analysis:" -ForegroundColor Cyan

    if ($policy.MaximumActiveAssignmentDuration -eq "PT0S" -or $policy.MaximumActiveAssignmentDuration -eq "" -or $null -eq $policy.MaximumActiveAssignmentDuration) {
        Write-Host "  ⚠️  MaximumActiveAssignmentDuration is disabled/zero - this blocks active assignments!" -ForegroundColor Red
    }

    if ($policy.ActivationDuration -eq "PT0S" -or $policy.ActivationDuration -eq "" -or $null -eq $policy.ActivationDuration) {
        Write-Host "  ⚠️  ActivationDuration is disabled/zero - this blocks activations!" -ForegroundColor Red
    }

    if ($policy.AllowPermanentActiveAssignment -eq "false" -and ($policy.MaximumActiveAssignmentDuration -eq "PT0S" -or $policy.MaximumActiveAssignmentDuration -eq "" -or $null -eq $policy.MaximumActiveAssignmentDuration)) {
        Write-Host "  ❌ CRITICAL: Permanent active assignments disabled AND MaximumActiveAssignmentDuration is zero/empty!" -ForegroundColor Red
        Write-Host "     This configuration prevents ALL active assignments." -ForegroundColor Red
    }

    Write-Host "`n✅ Policy diagnostic complete" -ForegroundColor Green

} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
