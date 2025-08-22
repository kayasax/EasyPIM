# Invoke-EasyPIMOrchestrator

## Synopsis
Runs the EasyPIM orchestrator to validate/apply PIM policies and reconcile assignments for Azure, Entra ID, and Groups from a single JSON configuration.

For a step-by-step walkthrough, see:
- EasyPIM Orchestrator Complete Tutorial: EasyPIM/Documentation/EasyPIM-Orchestrator-Complete-Tutorial.md
- Progressive Validation Guide (safe WhatIf runbook): EasyPIM/Documentation/Progressive-Validation-Guide.md

## Syntax

File configuration
```powershell
Invoke-EasyPIMOrchestrator \
  -ConfigFilePath <String> \
  [-TenantId <String>] [-SubscriptionId <String>] \
  [-Mode <delta|initial>] \
  [-Operations <String[]>] [-PolicyOperations <String[]>] \
  [-SkipPolicies] [-SkipAssignments] [-SkipCleanup] \
  [-WouldRemoveExportPath <String>] \
  [-WhatIf] [-Verbose]
```

Key Vault configuration
```powershell
Invoke-EasyPIMOrchestrator \
  -KeyVaultName <String> -SecretName <String> \
  [-TenantId <String>] [-SubscriptionId <String>] \
  [-Mode <delta|initial>] \
  [-Operations <String[]>] [-PolicyOperations <String[]>] \
  [-SkipPolicies] [-SkipAssignments] [-SkipCleanup] \
  [-WouldRemoveExportPath <String>] \
  [-WhatIf] [-Verbose]
```

## Description
Processes policies first, then cleanup, then assignments. With -WhatIf, policies run in validation mode (no writes) and assignments are previewed. Without -WhatIf, policies and assignments are applied in delta mode by default (or initial when -Mode initial is used).

Key behavior highlights:
- Entra approvals use Graph subject sets (@odata.type + userId/groupId)
- Eligibility durations normalize PnY → PnD when required by Graph; maximumDuration only included when isExpirationRequired=true
- If an Authentication Context is enabled, MFA is removed from EndUser enablement to avoid conflicts; the enablement rule is still emitted to clear prior configuration
- On InvalidPolicy, the orchestrator logs the full PATCH body and can isolate failing rules by patching rules individually for diagnostics
- AU-scoped Entra assignments are detected but not auto-removed due to API limitations; they are reported for manual review

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| KeyVaultName | String | Yes (Key Vault mode) | | Azure Key Vault name that stores the JSON configuration |
| SecretName | String | Yes (Key Vault mode) | | Secret name containing the JSON configuration |
| ConfigFilePath | String | Yes (File mode) | | Local path to a JSON configuration file |
| TenantId | String | No | $env:TENANTID | Azure tenant ID (fallback to environment variable if omitted) |
| SubscriptionId | String | No | $env:SUBSCRIPTIONID | Azure subscription ID (fallback to environment variable if omitted) |
| Mode | String | No | delta | Reconcile mode for assignments: delta or initial |
| Operations | String[] | No | All | Assignment domains to process: All, AzureRoles, EntraRoles, GroupRoles |
| PolicyOperations | String[] | No | Mirrors -Operations | Policy domains to process: All, AzureRoles, EntraRoles, GroupRoles |
| SkipPolicies | Switch | No | $false | Skip policy processing |
| SkipAssignments | Switch | No | $false | Skip assignment creation/reconciliation |
| SkipCleanup | Switch | No | $false | Skip cleanup (do not remove assignments) |
| WouldRemoveExportPath | String | No | | Path to export planned/actual removals (JSON default, supports CSV when .csv extension is used) |
| WhatIf | Switch | No | $false | Show what would change without applying it |
| Verbose | Switch | No | $false | Emit detailed logs for troubleshooting |

## Examples

Validate policies only (no writes)
```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath C:\Config\pim.json -SkipAssignments -PolicyOperations EntraRoles -WhatIf
```

Apply policies only (delta) from Key Vault
```powershell
Invoke-EasyPIMOrchestrator -KeyVaultName MyVault -SecretName PIMConfig -SkipAssignments -PolicyOperations AzureRoles
```

Default delta run (policies + cleanup + assignments)
```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath C:\Config\pim.json
```

Initial mode (aggressive cleanup; confirmation required)
```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath C:\Config\pim.json -Mode initial
```

Preview with export of planned removals
```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath C:\Config\pim.json -Mode initial -WhatIf -WouldRemoveExportPath .\LOGS\preview.csv
```

Skip cleanup for targeted assignment changes
```powershell
Invoke-EasyPIMOrchestrator -KeyVaultName MyVault -SecretName PIMConfig -SkipCleanup
```

## Notes
- Policies don’t have a separate PolicyMode. Use -WhatIf to validate (no writes); without -WhatIf, policies are applied in delta mode.
- Use $env:TENANTID and $env:SUBSCRIPTIONID for non-interactive runs.

## Related links
- Enhanced Policy Usage: EasyPIM/Documentation/Enhanced-Orchestrator-Policy-Usage.md
- EasyPIM Orchestrator Complete Tutorial (step-by-step): EasyPIM/Documentation/EasyPIM-Orchestrator-Complete-Tutorial.md
- Progressive Validation Guide: EasyPIM/Documentation/Progressive-Validation-Guide.md

