# Validate drift, then apply configuration changes with EasyPIM.Orchestrator
Import-Module EasyPIM.Orchestrator

$tenantId = Read-Host "Enter the Entra tenant ID"
$configurationPath = Resolve-Path "./config/pim-configuration.json"

Test-PIMPolicyDrift -TenantId $tenantId -ConfigurationPath $configurationPath | Out-String

Invoke-EasyPIMOrchestrator \
    -TenantId $tenantId \
    -ConfigurationPath $configurationPath \
    -PolicyMode Delta \
    -WhatIf:$false