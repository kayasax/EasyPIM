# Fix User Administrator Policy Script
Write-Host "=== User Administrator Policy Fix ===" -ForegroundColor Cyan

# Import EasyPIM module
Import-Module EasyPIM -Force

Write-Host "Current policy state:" -ForegroundColor Yellow
try {
    $currentPolicy = Get-PIMEntraRolePolicy -tenantID $env:TENANTID -rolename "User Administrator"
    Write-Host "  MaximumActiveAssignmentDuration: $($currentPolicy.MaximumActiveAssignmentDuration)" -ForegroundColor Red
    Write-Host "  AllowPermanentActiveAssignment: $($currentPolicy.AllowPermanentActiveAssignment)"
    Write-Host "  ActivationDuration: $($currentPolicy.ActivationDuration)"
    Write-Host "  ApprovalRequired: $($currentPolicy.ApprovalRequired)"
} catch {
    Write-Host "Error getting current policy: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nApplying HighSecurity template settings..." -ForegroundColor Green

try {
    # Apply the HighSecurity template settings
    Set-PIMEntraRolePolicy -tenantID $env:TENANTID -rolename "User Administrator" `
        -MaximumActiveAssignmentDuration "P30D" `
        -AllowPermanentActiveAssignment $false `
        -ActivationDuration "PT2H" `
        -ActivationRequirement "MultiFactorAuthentication,Justification" `
        -ApprovalRequired $true

    Write-Host "SUCCESS: User Administrator policy updated!" -ForegroundColor Green

    # Verify the change
    Write-Host "`nVerifying policy update:" -ForegroundColor Cyan
    $updatedPolicy = Get-PIMEntraRolePolicy -tenantID $env:TENANTID -rolename "User Administrator"
    Write-Host "  MaximumActiveAssignmentDuration: $($updatedPolicy.MaximumActiveAssignmentDuration)" -ForegroundColor Green
    Write-Host "  AllowPermanentActiveAssignment: $($updatedPolicy.AllowPermanentActiveAssignment)"
    Write-Host "  ActivationDuration: $($updatedPolicy.ActivationDuration)"
    Write-Host "  ApprovalRequired: $($updatedPolicy.ApprovalRequired)"

} catch {
    Write-Host "ERROR applying policy: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Test assignment creation ===" -ForegroundColor Cyan
try {
    Write-Host "Testing assignment with PT8H duration..."
    New-PIMEntraRoleActiveAssignment -tenantID $env:TENANTID -rolename "User Administrator" -principalID "8b0995d0-4c07-4814-98c8-550dc0af62cf" -duration "PT8H" -justification "Test after policy fix"
    Write-Host "SUCCESS: Assignment created!" -ForegroundColor Green
} catch {
    Write-Host "ERROR creating assignment: $($_.Exception.Message)" -ForegroundColor Red
}
