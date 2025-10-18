# Restore Entra role and Azure RBAC assignments from a saved export
Import-Module EasyPIM

$tenantId = Read-Host "Enter the Entra tenant ID"
$importPath = Resolve-Path "./Baseline/Assignments"

Import-PIMEntraRoleAssignment -TenantId $tenantId -Path $importPath -WhatIf
Import-PIMAzureResourceAssignment -TenantId $tenantId -Path $importPath -WhatIf

Write-Host "Review the WhatIf output, then rerun without -WhatIf to apply."