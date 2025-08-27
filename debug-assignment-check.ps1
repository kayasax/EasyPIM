# Test script to debug group assignment existence check
param(
    [string]$TenantId = $env:TENANTID,
    [string]$GroupId = "b08e4e66-2d4c-4804-be04-f37d2b038342",
    [string]$PrincipalId = "dcd31c16-eba2-4a6e-bf69-3c3d402b242b",
    [string]$Type = "member"
)

Write-Host "=== Testing Group Assignment Existence Check ===" -ForegroundColor Yellow
Write-Host "TenantId: $TenantId"
Write-Host "GroupId: $GroupId"
Write-Host "PrincipalId: $PrincipalId"
Write-Host "Type: $Type"
Write-Host ""

try {
    # Import the module
    Import-Module ".\EasyPIM\EasyPIM.psd1" -Force

    Write-Host "1. Testing Get-PIMGroupEligibleAssignment..." -ForegroundColor Cyan
    $eligResult = Get-PIMGroupEligibleAssignment -tenantID $TenantId -groupID $GroupId -principalID $PrincipalId -type $Type -Verbose
    Write-Host "Eligible assignments found: $($eligResult | Measure-Object | Select-Object -ExpandProperty Count)"
    if ($eligResult) {
        Write-Host "Details:" -ForegroundColor Red
        $eligResult | Format-Table -AutoSize
    }

    Write-Host "`n2. Testing Get-PIMGroupActiveAssignment..." -ForegroundColor Cyan
    $activeResult = Get-PIMGroupActiveAssignment -tenantID $TenantId -groupID $GroupId -principalID $PrincipalId -type $Type -Verbose
    Write-Host "Active assignments found: $($activeResult | Measure-Object | Select-Object -ExpandProperty Count)"
    if ($activeResult) {
        Write-Host "Details:" -ForegroundColor Red
        $activeResult | Format-Table -AutoSize
    }

    Write-Host "`n3. Combined check (as orchestrator does)..." -ForegroundColor Cyan
    $exists = $eligResult -or $activeResult
    Write-Host "Assignment exists: $exists" -ForegroundColor $(if ($exists) { "Red" } else { "Green" })

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "StackTrace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}
