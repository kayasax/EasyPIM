#!/usr/bin/env pwsh
# Quick syntax test for the Initialize function

try {
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content "EasyPIM\internal\functions\Initialize-EasyPIMPolicies.ps1" -Raw), [ref]$null)
    Write-Host "✅ Initialize-EasyPIMPolicies.ps1 syntax is valid" -ForegroundColor Green
} catch {
    Write-Host "❌ Initialize-EasyPIMPolicies.ps1 has syntax error: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content "EasyPIM\functions\New-PIMEntraRoleActiveAssignment.ps1" -Raw), [ref]$null)
    Write-Host "✅ New-PIMEntraRoleActiveAssignment.ps1 syntax is valid" -ForegroundColor Green
} catch {
    Write-Host "❌ New-PIMEntraRoleActiveAssignment.ps1 has syntax error: $($_.Exception.Message)" -ForegroundColor Red
}
