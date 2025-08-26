# Quick test to verify filtering logic
Import-Module .\EasyPIM.Orchestrator\EasyPIM.Orchestrator.psd1 -Force

# Test with minimal GroupRoles operation
Write-Host "Testing GroupRoles filtering..." -ForegroundColor Cyan

try {
    $result = Invoke-EasyPIMOrchestrator -ConfigFilePath tests\validation.json -TenantId $env:TENANTID -SubscriptionId $env:SUBSCRIPTIONID -skipPolicies -Operations GroupRoles -Verbose -WhatIf
    Write-Host "SUCCESS: Command completed" -ForegroundColor Green
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
