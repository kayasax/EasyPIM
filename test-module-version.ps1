# Simple test to verify our function version is loaded and working
Import-Module "d:\WIP\EASYPIM\EasyPIM" -Force

Write-Host "=== MODULE VERSION CHECK ===" -ForegroundColor Cyan
$functionPath = (Get-Command New-PIMEntraRoleActiveAssignment).ScriptBlock.File
Write-Host "Function loaded from: $functionPath"

# Check if our debug code is in the loaded version
$hasDebug = (Get-Command New-PIMEntraRoleActiveAssignment).ScriptBlock.ToString() -match "DEBUG: Input duration"
Write-Host "Contains debug code: $hasDebug" -ForegroundColor $(if($hasDebug) {"Green"} else {"Red"})

# Test the direct execution path that would be called by orchestrator
Write-Host "`n=== TESTING NORMALIZATION PATH ===" -ForegroundColor Cyan
try {
    # This will fail fast but should show debug output if our version is loaded
    $params = @{
        tenantID = "test-tenant"
        rolename = "Security Reader"
        principalID = "test-principal"
        duration = "P1H"
        justification = "test"
    }

    Write-Host "Calling with parameters:" -ForegroundColor Yellow
    $params | Format-Table -AutoSize

    New-PIMEntraRoleActiveAssignment @params
} catch {
    Write-Host "Expected error occurred: $($_.Exception.Message.Split("`n")[0])" -ForegroundColor Red
}

Write-Host "`n=== CONCLUSION ===" -ForegroundColor Cyan
if ($hasDebug -and $functionPath -like "*WIP*EASYPIM*") {
    Write-Host "✅ Local development version with debug is loaded" -ForegroundColor Green
} else {
    Write-Host "❌ Wrong version is loaded - this explains audit log failures" -ForegroundColor Red
}
