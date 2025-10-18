# Safely export current Entra role configuration for baselining
Import-Module EasyPIM

$tenantId = Read-Host "Enter the Entra tenant ID"
$exportPath = Join-Path -Path (Get-Location) -ChildPath "Baseline"

if (-not (Test-Path -Path $exportPath)) {
    New-Item -Path $exportPath -ItemType Directory | Out-Null
}

Export-PIMEntraRolePolicy -TenantId $tenantId -OutputPath $exportPath -IncludeAssignments
Export-PIMAzureResourcePolicy -TenantId $tenantId -OutputPath $exportPath -IncludeAssignments

Write-Host "Baseline exported to $exportPath"