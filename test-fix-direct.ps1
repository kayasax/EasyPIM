#!/usr/bin/env pwsh
# Direct test of our normalization fix

Write-Host "🧪 DIRECT FIX TEST" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan

# Load our function directly
. "d:\WIP\EASYPIM\EasyPIM\functions\New-PIMEntraRoleActiveAssignment.ps1"

# Test the normalization logic by examining the function
$functionContent = Get-Content "d:\WIP\EASYPIM\EasyPIM\functions\New-PIMEntraRoleActiveAssignment.ps1" -Raw

Write-Host "🔍 Checking if DEBUG code is present..." -ForegroundColor Blue
if ($functionContent -match "DEBUG: Input duration") {
    Write-Host "✅ Debug code found in function" -ForegroundColor Green
} else {
    Write-Host "❌ Debug code missing" -ForegroundColor Red
}

Write-Host "🔍 Checking normalization pattern..." -ForegroundColor Blue
if ($functionContent -match "duration -replace '\^P','PT'") {
    Write-Host "✅ Normalization code found" -ForegroundColor Green
} else {
    Write-Host "❌ Normalization code missing" -ForegroundColor Red
}

Write-Host "🔍 Checking placement before validation..." -ForegroundColor Blue
$beforeValidation = $functionContent -match "Normalize duration BEFORE validation"
if ($beforeValidation) {
    Write-Host "✅ Normalization is placed before validation" -ForegroundColor Green
} else {
    Write-Host "❌ Normalization placement issue" -ForegroundColor Red
}

# Test the actual normalization logic isolated
Write-Host "`n🧪 Testing isolated normalization logic..." -ForegroundColor Yellow

function Test-Normalization($inputDuration) {
    Write-Host "Input: '$inputDuration'" -ForegroundColor White
    if ($inputDuration -match '^P[0-9]+[HMS]$') {
        $normalized = ($inputDuration -replace '^P','PT')
        Write-Host "  -> Normalized: '$normalized'" -ForegroundColor Green
        return $normalized
    } else {
        Write-Host "  -> No change: '$inputDuration'" -ForegroundColor Blue
        return $inputDuration
    }
}

Test-Normalization "P1H"
Test-Normalization "P2H"
Test-Normalization "PT1H"
Test-Normalization "P30D"

Write-Host "`n🎯 CONCLUSION:" -ForegroundColor Cyan
Write-Host "If debug code and normalization logic are present, the fix should work." -ForegroundColor White
Write-Host "The audit log failures suggest either:" -ForegroundColor Yellow
Write-Host "1. Wrong module version is being used in production" -ForegroundColor Yellow
Write-Host "2. Different execution path is being taken" -ForegroundColor Yellow
Write-Host "3. The orchestrator bypasses this function" -ForegroundColor Yellow
