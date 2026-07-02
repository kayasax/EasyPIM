# Invoke-EasyPIMAssignmentRenewal

Proactively extends Azure resource role PIM assignments (eligible and active) that are declared in an EasyPIM
orchestrator configuration and are expiring within a threshold (default 14 days). Uses the ARM `AdminExtend`
request type, which requires no approval, so it can run unattended in a pipeline or runbook.

## Scope

- **v1 supports Azure resource roles only.** Entra directory roles and PIM-for-Groups are not yet supported.
- Only assignments **declared in the configuration** are extended. Live assignments not present in the
  configuration are never touched.
- Matching is by exact scope. An assignment **inherited** from a higher scope (for example, a management
  group) whose configured scope is a child subscription is treated as not-live at the configured scope and
  is skipped. Declare the assignment at the scope where it actually exists to have it renewed.

## Parameters

| Parameter | Description |
| --- | --- |
| `ConfigFilePath` | Path to the JSON/JSONC orchestrator configuration file. |
| `KeyVaultName` / `SecretName` | Load the configuration from a Key Vault secret instead of a file. |
| `TenantId` | Target tenant GUID. Falls back to `$env:tenantid`. |
| `SubscriptionId` | Target subscription GUID. Falls back to `$env:subscriptionid`. |
| `ThresholdDays` | Extend assignments expiring within this many days. Default `14`. |

## Behaviour

- The new end date is `now + policy maximum assignment duration`, clamped to the role policy.
- If a role policy allows permanent assignment but has no maximum duration, the assignment is skipped with a
  note recommending a permanent assignment instead.
- Idempotent: an assignment already extended past the threshold is not a candidate, and the core cmdlets skip a
  submission when an `AdminExtend` request for the same schedule is already in flight.
- Supports `-WhatIf` and returns a summary object (`FoundExpiring`, `Extended`, `Skipped`, `Details`).

## Examples

```powershell
# Preview
Invoke-EasyPIMAssignmentRenewal -ConfigFilePath .\pim-config-azure.jsonc -TenantId $t -SubscriptionId $s -WhatIf

# Apply
Invoke-EasyPIMAssignmentRenewal -ConfigFilePath .\pim-config-azure.jsonc -TenantId $t -SubscriptionId $s

# Weekly unattended run (scheduled task / runbook)
Invoke-EasyPIMAssignmentRenewal -KeyVaultName kv-easypim -SecretName pim-config -TenantId $t -SubscriptionId $s
```

## See also

- <https://github.com/kayasax/EasyPIM>
- <https://learn.microsoft.com/azure/templates/microsoft.authorization/roleeligibilityschedulerequests>
