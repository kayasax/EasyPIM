#!/usr/bin/env pwsh
# Test the expiration fix manually

# Check the current directory and try to test locally
Set-Location "d:\WIP\EASYPIM"

# Import without automatic loading to avoid conflicts
Import-Module .\EasyPIM.Orchestrator -Force -Global

Write-Host "🔍 Testing EasyPIM Orchestrator import..." -ForegroundColor Cyan
Get-Module EasyPIM*

Write-Host "🔍 Testing Initialize function..." -ForegroundColor Cyan
try {
    # Just check if the function exists and can be invoked (dry run)
    $cmd = Get-Command Initialize-EasyPIMPolicies -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "✅ Initialize-EasyPIMPolicies function found: $($cmd.Source)" -ForegroundColor Green
    } else {
        Write-Host "❌ Initialize-EasyPIMPolicies function NOT found" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error testing Initialize function: $($_.Exception.Message)" -ForegroundColor Red
}
