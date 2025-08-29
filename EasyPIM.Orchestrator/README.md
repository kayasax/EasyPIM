# EasyPIM.Orchestrator

JSON-driven orchestration for EasyPIM. This module runs end-to-end PIM configuration from a single JSON file.

## Requirements
- PowerShell 5.1 or 7.x
- EasyPIM ≥ 1.10.0 (installed automatically when importing this module)

## Install
```pwsh
Install-Module EasyPIM -MinimumVersion 2.0.2 -Scope CurrentUser
Install-Module EasyPIM.Orchestrator -Scope CurrentUser
```

## Commands
- Invoke-EasyPIMOrchestrator – execute the JSON-driven flow
- Test-PIMPolicyDrift – compare live vs. config
- Test-PIMEndpointDiscovery – validate API endpoints for cloud environments

```pwsh
Import-Module EasyPIM.Orchestrator
Get-Command -Module EasyPIM.Orchestrator
```

## Quick start
```pwsh
$tenant = '<tenantId>'
$sub    = '<subscriptionId>'
$config = '.\\pim-config.json'
Invoke-EasyPIMOrchestrator -ConfigFilePath $config -TenantId $tenant -SubscriptionId $sub -Mode initial -WhatIf -WouldRemoveExportPath .\\LOGS
```

## Notes
- This module is published separately on the Gallery: https://www.powershellgallery.com/packages/EasyPIM.Orchestrator
- CI tag to trigger orchestrator build/publish: `orchestrator-v*`
