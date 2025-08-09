> By default, `Backup-PIMAzureResourcePolicy` works at the subscription level. If you want to back up policies at a different scope, you can use the `-scope` parameter instead of `-subscriptionID`.
# EasyPIM Progressive Validation Runbook

A safe, step-by-step plan to validate the orchestrator and policies in a real tenant. Each step includes a minimal JSON and a preview (-WhatIf) run before applying.

## Prerequisites

- TenantId and SubscriptionId for the target environment
- Principal Object IDs (Users/Groups/Service Principals) to test with
- EasyPIM module installed and authenticated context
- Path for your config file, e.g., `C:\Config\pim-config.json`

Tip: Keep one file and replace/append sections as you move through steps.


## Step 0 — Backup current policies (once)

> **Note:** This step may take up to an hour depending on the number of roles and policies in your tenant.

Commands

```powershell
# It is recommended to specify a path for the backup file:
Backup-PIMEntraRolePolicy -tenantID $env:TenantID -path C:\Temp\pimentrapolicybackup.csv
Backup-PIMAzureResourcePolicy -tenantID $env:TenantID -subscriptionID $env:SubscriptionID -path C:\Temp\pimazureresourcepolicybackup.csv
```

## Step 1 — Minimal config: ProtectedUsers only

Write pim-config.json

```json
{
  "ProtectedUsers": [
    "00000000-0000-0000-0000-000000000001"
  ]
}
```

Preview

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf
```

## Step 2 — Entra role policy (inline)



Write pim-config.json (always keep `ProtectedUsers` first; you can add comments for clarity):

> **Warning:** If `ApprovalRequired` is true, you must specify at least one approver in the `Approvers` array.

```jsonc
{
  // Object IDs for which assignments will not be removed
  "ProtectedUsers": [
    "00000000-0000-0000-0000-000000000001" // Example: Breakglass account
  ],
  "EntraRoles": {
    "Policies": {
      "User Administrator": {
        "ActivationDuration": "PT2H",
        "ActivationRequirement": "MultiFactorAuthentication,Justification",
        "ApprovalRequired": true,
        "Approvers": [
          { "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "description": "PIM Approver 1" }
        ]
      }
    }
  }
}
```

Preview (policies only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

## Step 3 — Entra role policy (template)


Write pim-config.json

```jsonc
{
  // Object IDs for which assignments will not be removed
  "ProtectedUsers": [
    "00000000-0000-0000-0000-000000000001" // Example: Breakglass account
  ],
  "PolicyTemplates": {
    // Default/normal template for most roles
    "Standard": {
      "ActivationDuration": "PT2H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": false
    },
    // High security template with advanced options
    "HighSecurity": {
      "ActivationDuration": "PT2H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": true,
      "Approvers": [
        { "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "description": "PIM Approver 1" }
      ],
      "AuthenticationContext_Enabled": true,
      "AuthenticationContext_Value": "c1:HighRiskOperations",
      "MaximumEligibilityDuration": "P90D",
      "MaximumActiveAssignmentDuration": "P30D",
      "Notifications": {
        "Eligibility": {
          "Alert": { "isDefaultRecipientEnabled": true,  "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
          "Assignee": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
          "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
        },
        "Active": {
          "Alert": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
          "Assignee": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
          "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
        },
        "Activation": {
          "Alert": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
          "Assignee": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
          "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
        }
      }
    }
  },
  "EntraRoles": {
    "Policies": {
      // Use Standard template for most roles
      "User Administrator": { "Template": "Standard" },
      // Use HighSecurity template for sensitive roles
      "Privileged Role Administrator": { "Template": "HighSecurity" }
    }
  }
}
```

Preview (policies only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

## Step 4 — Entra role policy (file/CSV, legacy import) [DEPRECATED]

> **Deprecated:** The `EntraRolePolicies` array with `PolicySource`/`PolicyFile` is a legacy import pattern and will be removed in a future release. Prefer the nested `EntraRoles.Policies` block with `Template` or inline properties for new configurations.


You can export an Entra role policy to CSV using `Export-PIMEntraRolePolicy`. This is useful for backup, migration, or editing policies outside the orchestrator. You can also use custom roles (e.g., `testrole`) for this process.

Example export command:

```powershell
# Export a policy for a custom role (e.g., 'testrole')
Export-PIMEntraRolePolicy -tenantID $env:TenantID -roleName "testrole" -path C:\Policies\testrole-policy.csv
```

Assumes you exported a CSV (e.g., `C:\Policies\entra-user-admin.csv` or `C:\Policies\testrole-policy.csv`).

Write pim-config.json

```json
{
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"],
  "EntraRolePolicies": [
    {
      "RoleName": "testrole", // Custom role example
      "PolicySource": "file",
      "PolicyFile": "C:\\Policies\\testrole-policy.csv"
    }
  ]
}
```

Preview (policies only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

## Step 5 — Entra role assignments (multiple assignments per role supported)

Note: The orchestrator supports multiple assignments per role in the Assignments block. Provide an array of assignment objects; each will be processed individually.

Note: The orchestrator supports a unified Assignments schema with an assignmentType field (Eligible or Active). This is parsed by Initialize-EasyPIMAssignments and mapped internally to legacy sections. If you prefer the legacy format, see the alternative below.

Note: `principalType` is optional in modern Assignments examples; the orchestrator infers the object type (User/Group/Service Principal) from the ID. It's kept only for legacy readability and can be omitted below.

Write pim-config.json

> **Note:** This config snippet only shows the Assignments block for Step 5. Policies defined in previous steps (such as EntraRoles or PolicyTemplates) can also be present in the same config file. End the Assignments block with a comma if you are including additional keys.

```jsonc
{
  "ProtectedUsers": [ //object ids for which the assignements will not be removed
    "7a55ec4d-028e-4ff1-8ee9-93da07b6d5d5" //Breakglass account
  ],
  "PolicyTemplates": {
    // Default/normal template for most roles
    "Standard": {
      "ActivationDuration": "PT8H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": false
    },
    // High security template with advanced options
    "HighSecurity": {
      "ActivationDuration": "PT2H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": true,
      "Approvers": [
        { "id": "2ab3f204-9c6f-409d-a9bd-6e302a0132db", "description": "IAM_approvers" }
      ],
      "AuthenticationContext_Enabled": true,
      "AuthenticationContext_Value": "c1:HighRiskOperations",
      "MaximumEligibilityDuration": "P90D",
      "MaximumActiveAssignmentDuration": "P30D",
      "Notifications": {
        "Eligibility": {
          "Alert": { "isDefaultRecipientEnabled": true,  "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
          "Assignee": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
          "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
        },
        "Active": {
          "Alert": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
          "Assignee": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
          "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
        },
        "Activation": {
          "Alert": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
          "Assignee": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
          "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
        }
      }
    }
  },
  "EntraRoles": {
    "Policies": {
      // Use Standard template for most roles
      "Guest Inviter": { "Template": "Standard" },
      "Testrole":{"Template":"Standard"},
      // Use HighSecurity template for sensitive roles
      "User Administrator": { "Template": "HighSecurity" }
    }
  },
  // Example assignments block
  "Assignments": {
    "EntraRoles": [
      {
        "roleName": "User Administrator",
        "assignments": [
          {
            "principalId": "f8b74308-47bf-4764-a31e-634e54c36212", //UserAdmin1 (ADM)
            "assignmentType": "Eligible",
            "justification": "My user Admins"
            // If duration is not specified, the orchestrator will use the maximum allowed by policy
          }
        ]
      },
      {
        "roleName": "Guest Inviter",
        "assignments": [
          {
            "principalId": "99999999-1111-2222-3333-444444444444", //GuestOpsUser1
            "assignmentType": "Eligible",
            "duration": "P30D", // Option example: explicit eligibility duration override
            "justification": "Guest onboarding rotation"
          },
          {
            "principalId": "99999999-5555-6666-7777-888888888888", //GuestOpsUser2
            "assignmentType": "Eligible",
            "permanent": true, // Option example: permanent eligibility (subject to policy allowing it)
            "justification": "Primary guest management"
          }
        ]
      }
    ]
  }
}
```

Preview (assignments only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipPolicies
```


Legacy alternative (same outcome using legacy sections):

```json
{
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"],
  "EntraIDRoles": [
    {
      "roleName": "User Administrator",
      "principalId": "11111111-1111-1111-1111-111111111111",
      "principalType": "User",
      "justification": "Ops rotation"
    }
  ],
  "EntraIDRolesActive": [
    {
      "roleName": "User Administrator",
      "principalId": "22222222-2222-2222-2222-222222222222",
      "principalType": "User",
      "duration": "PT8H",
      "justification": "Break-glass"
    }
  ]
}
```

Multiple principals

- Unified Assignments pattern: add multiple items under assignments[] for the same role.

```json
{
  "Assignments": {
    "EntraRoles": [
      {
        "roleName": "User Administrator",
        "assignments": [
          { "principalId": "11111111-1111-1111-1111-111111111111", "principalType": "User", "assignmentType": "Eligible", "justification": "Ops rotation" },
          { "principalId": "22222222-2222-2222-2222-222222222222", "assignmentType": "Eligible", "justification": "Ops rotation" }
        ]
      }
    ]
  }
}
```

- Legacy pattern: use PrincipalIds (with an S) to batch expand in one entry.

```json
{
  "EntraIDRoles": [
    {
      "RoleName": "User Administrator",
      "PrincipalIds": [
        "11111111-1111-1111-1111-111111111111",
        "22222222-2222-2222-2222-222222222222"
      ],
      "PrincipalType": "User",
      "Justification": "Ops rotation"
    }
  ]
}
```

## Step 6 — Azure role policy (inline; Scope is required)

Goal: Introduce your first Azure Role policy while preserving everything validated in Step 5 (ProtectedUsers, Entra role policy templates & assignments). Keep `ProtectedUsers` first for safety.

IMPORTANT: Some Azure built‑in roles are treated as protected in the orchestrator and their policies are intentionally not changed for safety (currently: "Owner" and "User Access Administrator"). If you try to target them you will see a [PROTECTED] message and no update occurs. For the first Azure policy example, use a non‑protected role such as "Reader" or "Contributor".

### Full context (carried forward + new Azure policy)
Use this if you maintain a single evolving file. Comments highlight what is NEW in this step.

```jsonc
{
  // Always first – prevents accidental removals
  "ProtectedUsers": [
    "00000000-0000-0000-0000-000000000001" // Breakglass account
  ],

  // From Step 5 (abbreviated for clarity)
  "PolicyTemplates": {
    "Standard": { "ActivationDuration": "PT8H", "ActivationRequirement": "MultiFactorAuthentication,Justification", "ApprovalRequired": false },
    "HighSecurity": { "ActivationDuration": "PT2H", "ActivationRequirement": "MultiFactorAuthentication,Justification", "ApprovalRequired": true, "Approvers": [ { "id": "2ab3f204-9c6f-409d-a9bd-6e302a0132db", "description": "IAM_approvers" } ] }
  },
  "EntraRoles": {
    "Policies": {
      "Guest Inviter": { "Template": "Standard" },
      "Testrole": { "Template": "Standard" },
      "User Administrator": { "Template": "HighSecurity" }
    }
  },
  "Assignments": {
    "EntraRoles": [
      {
        "roleName": "User Administrator",
        "assignments": [
          { "principalId": "f8b74308-47bf-4764-a31e-634e54c36212", "assignmentType": "Eligible", "justification": "My user Admins" }
        ]
      },
      {
        "roleName": "Guest Inviter",
        "assignments": [
          { "principalId": "99999999-1111-2222-3333-444444444444", "assignmentType": "Eligible", "duration": "P30D", "justification": "Guest onboarding rotation" },
          { "principalId": "99999999-5555-6666-7777-888888888888", "assignmentType": "Eligible", "permanent": true, "justification": "Primary guest management" }
        ]
      }
    ]
  },

  // NEW in Step 6 (inline Azure policy for a NON-PROTECTED role: Reader)
  "AzureRoles": {
    "Policies": {
      "Reader": {
        "Scope": "/subscriptions/<sub-guid>",
        "ActivationDuration": "PT1H",
        "ActivationRequirement": "MultiFactorAuthentication",
        "ApprovalRequired": false
      }
    }
  }
}
```

### Minimal delta snippet
If you prefer to patch in just the new portion (assumes the earlier sections already exist above this block in your file):

```jsonc
{
  "AzureRoles": {
    "Policies": {
      "Reader": {
        "Scope": "/subscriptions/<sub-guid>",
        "ActivationDuration": "PT1H",
        "ActivationRequirement": "MultiFactorAuthentication",
        "ApprovalRequired": false
      }
    }
  }
}
```

Preview (policies only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

## Step 7 — Azure role policy (template)

Goal: Show the SMALL change from Step 6 (inline Azure policy) to a template-based Azure policy. Everything else from Step 6 stays the same. You have TWO equivalent options:

1. Convert the SAME role (Reader) from inline properties to a template reference.
2. Keep the original inline Reader policy and ADD a new template-based low-impact role (e.g. Tag Contributor) — useful if you want to compare side‑by‑side once.

Below are both patterns with an explicit, minimal diff so you can “see” the change clearly.

### A. Convert existing inline role (RECOMMENDED simplest path)

Step 6 Azure block (before):
```jsonc
"AzureRoles": {
  "Policies": {
    "Reader": {
      "Scope": "/subscriptions/<sub-guid>",
      "ActivationDuration": "PT1H",
      "ActivationRequirement": "MultiFactorAuthentication",
      "ApprovalRequired": false
    }
  }
}
```

Step 7 replacement (after):
```jsonc
"AzureRoles": {
  "Policies": {
    "Reader": {
      "Scope": "/subscriptions/<sub-guid>",
      "Template": "Standard" // <— inline properties replaced by a template reference
    }
  }
}
```

Minimal delta (diff style):
```diff
  "AzureRoles": {
    "Policies": {
      "Reader": {
        "Scope": "/subscriptions/<sub-guid>",
-       "ActivationDuration": "PT1H",
-       "ActivationRequirement": "MultiFactorAuthentication",
-       "ApprovalRequired": false
+       "Template": "Standard"
      }
    }
  }
```

### B. Add a second template-based role (keep original inline for one step)

If you prefer to SEE both forms once, append only the new role (using Tag Contributor which has narrower scope than full Contributor):
```jsonc
"AzureRoles": {
  "Policies": {
    "Reader": {  // unchanged inline from Step 6
      "Scope": "/subscriptions/<sub-guid>",
      "ActivationDuration": "PT1H",
      "ActivationRequirement": "MultiFactorAuthentication",
      "ApprovalRequired": false
    },
  "Tag Contributor": { // NEW template-based (low-impact)
      "Scope": "/subscriptions/<sub-guid>",
      "Template": "Standard"
    }
  }
}
```

Later (Step 8 or whenever ready) you can delete the inline Reader block or convert it (Option A) to keep everything template-driven.

### Full context (abbreviated) with Option A applied
Only unchanged sections are compressed for readability.

```jsonc
{
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"],
  "PolicyTemplates": {
    "Standard": { "ActivationDuration": "PT8H", "ActivationRequirement": "MultiFactorAuthentication,Justification", "ApprovalRequired": false },
    "HighSecurity": { "ActivationDuration": "PT2H", "ActivationRequirement": "MultiFactorAuthentication,Justification", "ApprovalRequired": true }
  },
  "EntraRoles": { "Policies": { "Guest Inviter": { "Template": "Standard" }, "Testrole": { "Template": "Standard" }, "User Administrator": { "Template": "HighSecurity" } } },
  "Assignments": { /* (same as Step 6, omitted for brevity) */ },
  "AzureRoles": {
    "Policies": {
      "Reader": { "Scope": "/subscriptions/<sub-guid>", "Template": "Standard" }
    }
  }
}
```

### Minimal delta snippet (copy/paste)
Pick ONE of these depending on Option A or B:

Option A (replace existing block):
```jsonc
{
  "AzureRoles": {
    "Policies": {
      "Reader": { "Scope": "/subscriptions/<sub-guid>", "Template": "Standard" }
    }
  }
}
```

Option B (append Tag Contributor):
```jsonc
{
  "AzureRoles": {
    "Policies": {
  "Tag Contributor": { "Scope": "/subscriptions/<sub-guid>", "Template": "Standard" }
    }
  }
}
```

Preview (policies only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

## Step 8 — (Optional / Deprecated) Azure role policy via CSV file import

Status: Deprecated. Skip this step unless you specifically need to bulk‑reapply a previously exported CSV.

Why it is deprecated:
- External CSV hides effective settings (harder to review in PRs).
- Inline / template JSON (Steps 6–7) is clearer and source‑controlled.
- Protected roles (e.g. Owner, User Access Administrator) should not be managed this way.

When to still use:
- One‑time migration of historical exports while converting to JSON templates.
- Audit comparison (export current -> diff -> discard).

Strong recommendation: Move directly from Step 7 to Step 9 unless you have a migration CSV in hand.

Example (safe, non‑privileged role). Replace only if you truly have a legacy CSV:

```jsonc
{
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"],
  "AzureRolePolicies": [
    {
      "RoleName": "Tag Contributor", // previously exported role policy
      "Scope": "/subscriptions/<sub-guid>",
      "PolicySource": "file",
      "PolicyFile": "C:\\Policies\\tag-contributor-policy.csv"
    }
  ]
}
```

Preview (policies only) — validation only; consider converting the resulting settings into a template afterwards:

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

Convert after preview (suggested workflow):
1. Export current policy (if not already) for traceability.
2. Run -WhatIf with CSV to confirm it matches expectations.
3. Translate CSV columns to a PolicyTemplate JSON entry.
4. Replace AzureRolePolicies block with AzureRoles.Policies using Template.
5. Delete / archive the CSV.

## Step 9 — Azure assignments (1 Eligible + 1 Active)

Write pim-config.json

```json
{
  "Assignments": {
    "AzureRoles": [
      {
  "roleName": "Tag Contributor",
        "scope": "/subscriptions/<sub-guid>",
        "assignments": [
          {
            "principalId": "33333333-3333-3333-3333-333333333333",
            "principalType": "Group",
            "assignmentType": "Eligible",
            "justification": "Team access"
          },
          {
            "principalId": "44444444-4444-4444-4444-444444444444",
            "principalType": "User",
            "assignmentType": "Active",
            "duration": "PT8H",
            "justification": "Maintenance window"
          }
        ]
      }
    ]
  },
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"]
}
```

Preview (assignments only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipPolicies
```

Multiple principals

- Unified Assignments pattern: add multiple items under assignments[] for the same role/scope.

```json
{
  "Assignments": {
    "AzureRoles": [
      {
  "roleName": "Tag Contributor",
        "scope": "/subscriptions/<sub-guid>",
        "assignments": [
          { "principalId": "33333333-3333-3333-3333-333333333333", "principalType": "Group", "assignmentType": "Eligible", "justification": "Team access" },
          { "principalId": "55555555-5555-5555-5555-555555555555", "principalType": "User", "assignmentType": "Eligible", "justification": "Team access" }
        ]
      }
    ]
  }
}
```

- Legacy pattern: use PrincipalIds (with an S) to batch expand in one entry.

```json
{
  "AzureRoles": [
    {
  "RoleName": "Tag Contributor",
      "Scope": "/subscriptions/<sub-guid>",
      "PrincipalIds": [
        "33333333-3333-3333-3333-333333333333",
        "55555555-5555-5555-5555-555555555555"
      ],
      "PrincipalType": "Group",
      "Justification": "Team access"
    }
  ]
}
```

## Step 10 — Optional: Groups

Policies for groups are validate-only right now. You can still test assignments.

Write pim-config.json

```json
{
  "Assignments": {
    "Groups": [
      {
        "groupId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        "roleName": "Member",
        "assignments": [
          {
            "principalId": "55555555-5555-5555-5555-555555555555",
            "principalType": "User",
            "assignmentType": "Eligible",
            "justification": "Project team"
          }
        ]
      }
    ]
  },
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"]
}
```

Preview (assignments only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipPolicies
```

## Step 11 — Apply changes (remove -WhatIf)

Apply policies

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -SkipAssignments
```

Apply assignments

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -SkipPolicies
```

---

## Verification Tips

- ActivationRequirement values are case-sensitive: `None`, `MultiFactorAuthentication`, `Justification`, `Ticketing` (combine with commas)
- Azure policies require `Scope`; Entra policies are directory-wide
- AU-scoped Entra cleanup isn’t automatic; remove manually if needed
- Keep break-glass accounts in `ProtectedUsers` at all times

## References

- See `EasyPIM-Orchestrator-Complete-Tutorial.md` for end-to-end context
- See `Configuration-Schema.md` for the full schema and field definitions

## Step 12 — Comprehensive policy validation (all options)

This step validates every main policy lever in a single run: durations, approvers, authentication context, and full notification matrix. Run with -WhatIf to preview safely.

Entra role (inline policy with all options)

```json
{
  "EntraRoles": {
    "Policies": {
      "User Administrator": {
        "ActivationDuration": "PT2H",
        "ActivationRequirement": "MultiFactorAuthentication,Justification,Ticketing",
        "ActiveAssignmentRequirement": "MultiFactorAuthentication,Justification",
        "ApprovalRequired": true,
        "Approvers": [
          { "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "description": "PIM Approver 1" },
          { "id": "ffffffff-1111-2222-3333-444444444444", "description": "PIM Approver Group" }
        ],
        "AllowPermanentEligibility": false,
        "MaximumEligibilityDuration": "P90D",
        "AllowPermanentActiveAssignment": false,
        "MaximumActiveAssignmentDuration": "P30D",
        "AuthenticationContext_Enabled": true,
        "AuthenticationContext_Value": "c1:HighRiskOperations",
        "Notifications": {
          "Eligibility": {
            "Alert": { "isDefaultRecipientEnabled": true,  "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
            "Assignee": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
            "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
          },
          "Active": {
            "Alert": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
            "Assignee": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
            "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
          },
          "Activation": {
            "Alert": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
            "Assignee": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
            "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
          }
        }
      }
    }
  },
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"]
}
```

Preview (policies only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

Azure role (inline policy with all options; Scope required)

```json
{
  "AzureRoles": {
    "Policies": {
      "Contributor": {
        "Scope": "/subscriptions/<sub-guid>",
        "ActivationDuration": "PT4H",
        "ActivationRequirement": "MultiFactorAuthentication,Justification",
        "ActiveAssignmentRequirement": "MultiFactorAuthentication",
  "AuthenticationContext_Enabled": true,
  "AuthenticationContext_Value": "c1:HighRiskOperations",
        "ApprovalRequired": true,
        "Approvers": [
          { "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "description": "PIM Approver 1" }
        ],
        "AllowPermanentEligibility": false,
        "MaximumEligibilityDuration": "P180D",
        "AllowPermanentActiveAssignment": false,
        "MaximumActiveAssignmentDuration": "P14D",
        "Notifications": {
          "Eligibility": {
            "Alert": { "isDefaultRecipientEnabled": true,  "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
            "Assignee": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
            "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
          },
          "Active": {
            "Alert": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
            "Assignee": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
            "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
          },
          "Activation": {
            "Alert": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
            "Assignee": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
            "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
          }
        }
      }
    }
  },
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"]
}
```

Preview (policies only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

Notes
- ActivationRequirement values are case-sensitive and comma-separated when combining.
- AuthenticationContext_* is supported for both Entra and Azure role policies.
- Approvers array accepts user or group object IDs; ApprovalRequired must be true for approvers to apply.
- The -WhatIf output prints durations, requirements, approvers count, authentication context (if enabled), and counts Notification_* settings.
