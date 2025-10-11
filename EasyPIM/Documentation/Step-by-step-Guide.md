# EasyPIM Progressive Validation Runbook (October 11, 2025)

A safe, step-by-step plan to exercise the orchestrator and policies in a real tenant. Each step includes a minimal JSON and a preview (-WhatIf) run before applying.

## Module Architecture Overview

EasyPIM is now split into two complementary modules:

- **EasyPIM** (Core Module): Provides individual PIM management functions for backup, restore, policy configuration, and assignment management. Use this for targeted operations and building custom scripts.

- **EasyPIM.Orchestrator**: Provides comprehensive configuration management through `Invoke-EasyPIMOrchestrator`, policy drift detection, and end-to-end workflows. This module depends on the core EasyPIM module.

This guide focuses on the orchestrator workflows, but individual core functions can be used independently for specific tasks.

## What's New in 2.0.30 / 1.4.7

- **Array-first configuration** – `EntraRoles.Policies`, `AzureRoles.Policies`, and `GroupPolicies` now accept array payloads in addition to the legacy dictionary format. Arrays make pull requests easier to read and enable per-entry metadata such as `PolicySource`.
- **Template overrides everywhere** – Template + inline overrides now work across Entra, Azure, and Group policies even when you use the array format. Only the properties you list in an entry override the template defaults.
- **Safer assignments** – Assignment reconciliation now matches both scope and role name, so inherited or unrelated assignments are no longer treated as duplicates. Status-only strings (for example, "0 assignment(s)") are ignored automatically.
- **Activation requirement hygiene** – Validation steps now remove stray `AuthenticationContext` tokens before deployment, preventing the common `MfaAndAcrsConflict` failure.

## Table of Contents

1. [Step 0 — Backup current policies (once)](#step-0)
2. [Step 1 — Minimal config: ProtectedUsers only](#step-1)
3. [Step 2 — Entra role policy (inline)](#step-2)
4. [Step 3 — Entra role policy (template + 🆕 template + inline override)](#step-3)
5. [Step 4 — Entra role assignments (multiple assignments per role supported)](#step-4)
6. [Step 5 — Azure role policy (inline; Scope is required)](#step-5)
7. [Step 6 — Azure role policy (template + 🆕 template + inline override)](#step-6)
8. [Step 7 — Azure assignments (1 Eligible + 1 Active)](#step-7)
9. [Step 8 — Optional: Groups (Policies + Assignments)](#step-8)
10. [Step 9 — Apply changes (remove -WhatIf)](#step-9)
11. [Step 10 — Use the Same Config from Azure Key Vault (Optional)](#step-10)
12. [Step 11 — (Optional, Destructive) Reconcile with initial mode](#step-11)
13. [Step 12 — Comprehensive policy validation (all options)](#step-12)
14. [Step 13 — Detect policy drift with Test-PIMPolicyDrift](#step-13)
15. [Step 14 — (Optional) CI/CD automation (GitHub Actions + Key Vault)](#step-14)
16. [Appendix — Tips & Safety Gates](#appendix)


## Prerequisites

- TenantId and SubscriptionId for the target environment
- Principal Object IDs (Users/Groups/Service Principals) to test with
- **EasyPIM modules installed and authenticated context:**
  - `EasyPIM` (core module) - provides backup, individual role management, and policy functions
  - `EasyPIM.Orchestrator` - provides orchestration capabilities (`Invoke-EasyPIMOrchestrator`)
- Path for your config file, e.g., `C:\Config\pim-config.json`

### Module Installation

```powershell
# Install both modules from PowerShell Gallery
Install-Module -Name EasyPIM -Scope CurrentUser
Install-Module -Name EasyPIM.Orchestrator -Scope CurrentUser

# Import modules (orchestrator automatically imports core as dependency)
Import-Module EasyPIM.Orchestrator
```

**Note:** The `EasyPIM.Orchestrator` module depends on the core `EasyPIM` module and will automatically import it. You can work with individual PIM functions using the core module alone, or use the orchestrator for comprehensive configuration management.

### Authentication Setup

Before running any commands, establish authenticated sessions:

```powershell
# Connect to Microsoft Graph (required for Entra ID PIM operations)
Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory"

# Connect to Azure (required for Azure resource PIM operations)
Connect-AzAccount
Set-AzContext -SubscriptionId "<your-subscription-id>"
```

**Note:** The orchestrator includes automatic connection checks and will prompt if authentication is missing.

Tip: Keep one file and replace/append sections as you move through steps.

## Configuration Format Quick Reference

You can express policies using either a **dictionary** (object where each property is the role name) or a **record array** (each policy is its own object in an array). Both shapes are supported for Entra, Azure, and Group policies. Pick whichever is easier for your source control strategy.

```jsonc
// Dictionary (legacy) style
{
  "EntraRoles": {
    "Policies": {
      "User Administrator": { "Template": "HighSecurity" }
    }
  }
}

// Array style (new in 1.4.7)
{
  "EntraRoles": {
    "Policies": [
      { "RoleName": "User Administrator", "Template": "HighSecurity" },
      { "RoleName": "Guest Inviter", "Policy": { "ActivationDuration": "PT4H" } }
    ]
  }
}
```

> ⚠️ Use **only one** format per policy block. If both are present the orchestrator stops with a validation error.

Array entries also accept optional metadata such as `PolicySource`, additional per-role overrides, or alternate template property names (`Template` or `PolicyTemplate`). The orchestrator normalizes both formats to the same internal model before validation.


<a id="step-0"></a>
## Step 0 — Backup current policies (once)

> **Note:** This step may take up to an hour depending on the number of roles and policies in your tenant.

> **Note:** Backup functions (`Backup-PIMEntraRolePolicy`, `Backup-PIMAzureResourcePolicy`) are provided by the core `EasyPIM` module.

> By default, `Backup-PIMAzureResourcePolicy` works at the subscription level. If you want to back up policies at a different scope, you can use the `-scope` parameter instead of `-subscriptionID`.

Commands

```powershell
# It is recommended to specify a path for the backup file:
Backup-PIMEntraRolePolicy -tenantID $env:TenantID -path C:\Temp\pimentrapolicybackup.csv
Backup-PIMAzureResourcePolicy -tenantID $env:TenantID -subscriptionID $env:SubscriptionID -path C:\Temp\pimazureresourcepolicybackup.csv
```

<a id="step-1"></a>
## Step 1 — Minimal config: ProtectedUsers only

Goal: Establish a safety baseline that guarantees your break‑glass / critical principals can never be removed by later reconciliation steps (especially Step 11 initial mode). `ProtectedUsers` is a hard exclusion list used by cleanup logic: any assignment held by these object IDs is always preserved (reported as Protected, never Removed / WouldRemove). Start with ONLY this section so you can preview the orchestration pipeline and principal validation without risking unintended deletions.

What to include:
* Break‑glass emergency access accounts (cloud‑only preferred, strong MFA)
* Core IAM / security operations groups or service principals that must retain standing access while you transition
* Accounts required to fix the system if later steps misconfigure policies

What NOT to include (anti‑patterns):
* Large generic groups (bloats permanent access and reduces visibility)
* Expired / personal test accounts (defeats cleanup objectives)
* Every admin in the tenant (use assignments + policies instead)

Best practices:
1. Keep the list short (aim for 1–5 principals).
2. Use GUIDs (object IDs) not display names to avoid ambiguity.
3. Revisit periodically; remove stale entries once confidence is high.
4. Never run initial (destructive) mode until this list is validated in a -WhatIf preview.

Write pim-config.json

```json
{
  "ProtectedUsers": [
    "00000000-0000-0000-0000-000000000001",//break glass account objectID
    "00000000-0000-0000-0000-000000000002"//IAM admins Group obejctID
  ]
}
```

Preview

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf
```

<a id="step-2"></a>
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

**Array format equivalent**

```jsonc
{
  "ProtectedUsers": [
    "00000000-0000-0000-0000-000000000001"
  ],
  "EntraRoles": {
    "Policies": [
      {
        "RoleName": "User Administrator",
        "Policy": {
          "ActivationDuration": "PT2H",
          "ActivationRequirement": "MultiFactorAuthentication,Justification",
          "ApprovalRequired": true,
          "Approvers": [
            { "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "description": "PIM Approver 1" }
          ]
        }
      }
    ]
  }
}
```
This example above uses only a subset of available options. Refer to [Step 12](#step-12--comprehensive-policy-validation-all-options) for the complete list of supported options.

Preview (policies only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

<a id="step-3"></a>
## Step 3 — Entra role policy (template)

Why templates? A PolicyTemplate lets you define a reusable policy profile once (durations, requirements, approvals, notifications, auth context, limits) and then reference it by name under multiple roles. Benefits:
* DRY & consistency – one edit propagates everywhere (e.g., change ActivationRequirement in Standard template and every role using it updates next run).
* Safer iteration – you preview a single template change impact across all roles (-WhatIf) before applying.
* Clear diffs – PRs show a small change in one template block instead of many duplicated inline edits.
* Easier promotion – copy a vetted template set from test → prod without hunting per‑role tweaks.
* Guardrails – high‑risk roles point to a hardened template (HighSecurity) while low‑risk roles stay on Standard.

> 💡 Tip: If your template or inline policy ever included the literal string `AuthenticationContext` inside `ActivationRequirement`, the latest validation logic automatically strips it before deployment. This keeps Azure from rejecting the payload with `MfaAndAcrsConflict` while still honoring any explicit `AuthenticationContext_Enabled` setting.

Override strategy (important): The current engine resolves either a Template OR an inline policy for a role; it does NOT merge a template plus per‑role overrides field‑by‑field. To “override” for a specific role you simply stop using the Template reference and replace it with a full inline policy object for that role. (Future enhancement could add partial overlay, but today it is a switch, not a merge.)

Practical pattern:
1. Start with templates for 90% of roles (Standard / HighSecurity, etc.).
2. If one role needs a deviation (e.g., shorter ActivationDuration), replace its `{ "Template": "Standard" }` with a full inline policy object and adjust only the differing fields (you can copy the template contents as a starting point).
3. If later the deviation is no longer needed, revert back to the template reference to rejoin centralized management.

Example override (template → inline):
```diff
  "EntraRoles": {
    "Policies": {
      "User Administrator": {
-       "Template": "HighSecurity"
+       "ActivationDuration": "PT1H",              // shortened for this role only
+       "ActivationRequirement": "MultiFactorAuthentication,Justification",
+       "ApprovalRequired": true,
+       "Approvers": [ { "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "description": "PIM Approver 1" } ],
+       "AuthenticationContext_Enabled": true,
+       "AuthenticationContext_Value": "c1:HighRiskOperations"
      }
    }
  }
```

Tip: Keep the number of distinct templates small; too many templates = implicit inline sprawl.

### 🆕 NEW in v1.1.0: Template + Inline Override Support

The orchestrator now supports combining templates with inline property overrides! This provides the best of both worlds: template consistency with targeted customization.

**Template + Override Example:**
```jsonc
{
  "EntraRoles": {
    "Policies": {
      "Global Administrator": {
        "Template": "HighSecurity",           // Base template provides most settings
        "ActivationDuration": "PT1H",        // Override: shorter than template's PT2H
        "MaximumEligibilityDuration": "P60D" // Override: shorter than template's P90D
        // All other HighSecurity properties (ApprovalRequired, Approvers, etc.) remain unchanged
      },
      "Exchange Administrator": {
        "Template": "Standard",               // Base template
        "ApprovalRequired": true,             // Override: add approval requirement
        "Approvers": [
          { "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "description": "Exchange Admins" }
        ]
      }
    }
  }
}
```

**Benefits:**
- **Consistency**: Most properties inherit from the template
- **Flexibility**: Override only the properties that need customization
- **Maintainability**: Template changes still propagate to non-overridden properties
- **Backward Compatibility**: Existing template-only and inline-only configurations continue to work

**Available for all policy types:** EntraRoles, AzureRoles, and GroupRoles all support template + override patterns.

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

**Array format with template overrides**

```jsonc
{
  "PolicyTemplates": {
    "Standard": {
      "ActivationDuration": "PT8H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification"
    },
    "HighSecurity": {
      "ActivationDuration": "PT2H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": true,
      "Approvers": [ { "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" } ]
    }
  },
  "EntraRoles": {
    "Policies": [
      { "RoleName": "User Administrator", "Template": "Standard" },
      {
        "RoleName": "Privileged Role Administrator",
        "Template": "HighSecurity",
        "ActivationDuration": "PT1H" // override just this property
      }
    ]
  }
}
```

Preview (policies only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

<a id="step-5"></a>
## Step 4 — Entra role assignments (multiple assignments per role supported)

Note: The orchestrator supports multiple assignments per role in the Assignments block. Provide an array of assignment objects; each will be processed individually.

Note: The orchestrator supports a unified Assignments schema with an assignmentType field (Eligible or Active). This is parsed by Initialize-EasyPIMAssignments and mapped internally to legacy sections. If you prefer the legacy format, see the alternative below.

Note: `principalType` is optional in modern Assignments examples; the orchestrator infers the object type (User/Group/Service Principal) from the ID. It's kept only for legacy readability and can be omitted below.

**New in 2.0.30:** assignment matching now requires both the scope **and** the role name to align with your config, and status-only strings returned by Azure are ignored. This prevents inherited assignments or stale status messages from being treated as matches. If an assignment shows as "skipped" in -WhatIf, double-check that the scope path exactly matches what you expect (subscriptions vs. resource groups).

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

<a id="step-6"></a>
## Step 6 — Azure role policy (inline; Scope is required)

Goal: Introduce your first Azure Role policy while preserving everything proven in Step 5 (ProtectedUsers, Entra role policy templates & assignments). Keep `ProtectedUsers` first for safety.

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

**Array format (same outcome)**

```jsonc
{
  "AzureRoles": {
    "Policies": [
      {
        "RoleName": "Reader",
        "Scope": "/subscriptions/<sub-guid>",
        "Policy": {
          "ActivationDuration": "PT1H",
          "ActivationRequirement": "MultiFactorAuthentication",
          "ApprovalRequired": false
        }
      }
    ]
  }
}
```

Preview (policies only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

<a id="step-7"></a>
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

Array style with template override:

```jsonc
"AzureRoles": {
  "Policies": [
    {
      "RoleName": "Reader",
      "Scope": "/subscriptions/<sub-guid>",
      "Template": "Standard",
      "ActivationRequirement": "Justification" // optional inline override while still inheriting the template
    }
  ]
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

### 🆕 Option C: Template + Inline Override (NEW in v1.1.0)
```jsonc
{
  "AzureRoles": {
    "Policies": {
      "Contributor": {
        "Scope": "/subscriptions/<sub-guid>",
        "Template": "HighSecurity",           // Base template
        "ActivationDuration": "PT30M",       // Override: shorter than template
        "MaximumActiveAssignmentDuration": "PT8H"  // Override: limit active time
        // All other HighSecurity properties (ApprovalRequired, etc.) remain from template
      }
    }
  }
}
```

This approach gives you the security baseline of HighSecurity template while customizing activation and assignment durations for the high-privilege Contributor role.

Preview (policies only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

<a id="step-7"></a>
## Step 7 — Azure assignments (1 Eligible + 1 Active)

Goal: Add first Azure role assignments without altering existing policies. Everything from Step 6 (Azure role policy with template + inline override) remains; we only append an `Assignments.AzureRoles` block.

### Diff from previous step (conceptual)
```diff
  {
    "ProtectedUsers": [ "00000000-0000-0000-0000-000000000001" ],
    "PolicyTemplates": { ... },
    "EntraRoles": { ... },
    "Assignments": {              // <— NEW section (already existed for EntraRoles earlier; now adding AzureRoles)
      "EntraRoles": [ ... ],       // (unchanged if present)
+     "AzureRoles": [
+       {
+         "roleName": "Tag Contributor",
+         "scope": "/subscriptions/<sub-guid>",
+         "assignments": [
+           { "principalId": "33333333-3333-3333-3333-333333333333", "principalType": "Group", "assignmentType": "Eligible", "justification": "Team access" },
+           { "principalId": "44444444-4444-4444-4444-444444444444", "principalType": "User", "assignmentType": "Active", "duration": "PT8H", "justification": "Maintenance window" }
+         ]
+       }
+     ]
    }
  }
```

### Full minimal snippet (only new Azure assignments)
Use this if previous sections already exist exactly as-is above in your file.
```jsonc
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
  }
}
```

### Full context example (assignments + ProtectedUsers only)
If you keep a compact working file focused on assignments delta:
```jsonc
{
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"],
  "Assignments": {
    "AzureRoles": [
      {
        "roleName": "Tag Contributor",
        "scope": "/subscriptions/<sub-guid>",
        "assignments": [
          { "principalId": "33333333-3333-3333-3333-333333333333", "principalType": "Group", "assignmentType": "Eligible", "justification": "Team access" },
          { "principalId": "44444444-4444-4444-4444-444444444444", "principalType": "User", "assignmentType": "Active", "duration": "PT8H", "justification": "Maintenance window" }
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

<a id="step-8"></a>
## Step 8 — Optional: Groups (Policies + Assignments)

Group policies ARE supported (Get-PIMGroupPolicy / Set-PIMGroupPolicy). The orchestrator resolves group policies via `GroupRoles.Policies` (preferred) or the deprecated `GroupPolicies` / `Policies.Groups` formats. We'll DEFINE a minimal policy first, then add assignments referencing it. This mirrors the security-first approach: establish guardrails (policy) before granting access (assignments).

> Heads-up: AuthenticationContext_* in a shared template is ignored for Group policies. You can leave it in the template for Entra/Azure roles, but it won’t be applied to Groups.

> NOTE: In `GroupRoles.Policies` you may use either the group GUID (treated as `GroupId`) or a readable display name key (treated as `GroupName`). The orchestrator will resolve `GroupName` to `GroupId` at runtime. For production/stable configs prefer GUIDs to avoid ambiguity when duplicate or renamed groups exist. Assignments still require an explicit `groupId` field.

> QUICK NOTE (Auto‑Deferral): If a Group policy targets a group that is not yet PIM‑eligible (e.g. on‑premises synced or not onboarded), the orchestrator now DEFERS that policy instead of failing. It records status `DeferredNotEligible`, proceeds with the rest of the run, then automatically retries those deferred group policies after the assignment phase. The final summary prints a `DEFERRED GROUP POLICIES` block showing Applied / Still Not Eligible / Failed counts. To resolve a persistent `Still Not Eligible` state: (1) ensure the group is a cloud security group (not synced or M365 type unsupported), (2) enable PIM for the group in the portal (preview blade), then re-run the orchestrator. No action needed if the group becomes eligible mid‑run; the retry will apply it.

### Context Recap (Where We Are Before Adding Groups)
Your config already contains (abbreviated):
```jsonc
{
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"],
  "PolicyTemplates": { "Standard": { /* PT2H activation etc. */ }, "HighSecurity": { /* approval + MFA */ } },
  "EntraRoles": { "Policies": { "User Administrator": { "Template": "HighSecurity" }, "Guest Inviter": { "Template": "Standard" } } },
  "AzureRoles": { "Policies": { "Reader": { /* inline minimal */ }, "Tag Contributor": { "Template": "Standard", "Scope": "/subscriptions/<sub>" } } },
  "Assignments": { /* Entra + Azure role assignments already previewed earlier */ }
}
```
We now introduce Group policies/assignments incrementally.

Flow in this step:
1. 10.1 Minimal inline policy only (no assignments) — WhatIf with -SkipAssignments
2. 10.2 Add assignments referencing that policy — WhatIf with -SkipPolicies
3. 10.3 (Optional) Introduce a reusable template

### 10.1 Minimal Group Policy (inline, no assignments yet)

Write pim-config.json (policy only + ProtectedUsers – kept FIRST for visibility)

```json
{
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"],
  "GroupRoles": {
    "Policies": {
      "MyPilotGroup": {
        "Member": {
          "ActivationDuration": "PT4H",
          "ActivationRequirement": ["Justification"]
        }
      }
    }
  }
}
```

Preview (policies only)

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

Apply (after preview) — delta is the default change mode; no special flag needed for standard incremental runs:

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -SkipAssignments
```

### 10.2 Add Assignments (policy already previewed)

Instead of a diff (harder to copy), here are clean before / after examples plus an appendable fragment.

Before (policies only):

```json
{
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"],
  "GroupRoles": {
    "Policies": {
      "MyPilotGroup": {
        "Member": {
          "ActivationDuration": "PT4H",
          "ActivationRequirement": ["Justification"]
        }
      }
    }
  }
}
```

After (assignments added – note comma before "Assignments"):

```json
{
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"],
  "GroupRoles": {
    "Policies": {
      "MyPilotGroup": {
        "Member": {
          "ActivationDuration": "PT4H",
          "ActivationRequirement": ["Justification"]
        }
      }
    }
  },
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
  }
}
```

Appendable fragment (paste just above the final closing brace of your existing JSON, ensuring the preceding block ends with a comma):

```jsonc
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
  }
```



  Preview (assignments only):

  ```powershell
  Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipPolicies
  ```

  Apply assignments (after validation):

  ```powershell
  Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -SkipPolicies
  ```

  ### 10.3 Template (Optional)

```diff
  "PolicyTemplates": {
    "Standard": { ... },
+   "GroupStandard": {
+     "ActivationDuration": "PT4H",
+     "ActivationRequirement": ["Justification"],
+     "ApprovalRequired": false
+   }
  }

  "GroupRoles": {
    "Policies": {
      "MyPilotGroup": {
-       "Member": { "ActivationDuration": "PT4H", "ActivationRequirement": ["Justification"] }
+       "Member": { "Template": "GroupStandard" }
      }
    }
  }
```

Result: cleaner reuse; future tweaks centralized.

### 🆕 10.4 Template + Inline Override (NEW in v1.1.0)

For groups that need most template properties but with specific customizations:

```jsonc
{
  "GroupRoles": {
    "Policies": {
      "HighSecurityGroup": {
        "Member": {
          "Template": "GroupStandard",        // Base template
          "ActivationDuration": "PT2H",      // Override: shorter than template's PT4H
          "ApprovalRequired": true           // Override: add approval requirement (you'll need to set approvers too)
        },
        "Owner": {
          "Template": "GroupStandard",       // Base template
          "ActivationDuration": "PT1H",     // Override: even shorter for owners
          "MaximumEligibilityDuration": "P30D"  // Override: shorter eligibility period
        }
      }
    }
  }
}
```

This approach lets you maintain consistency with the template while customizing security requirements for sensitive groups.

NOTE: Deprecated formats (`GroupPolicies` array or nested `Policies.Groups`) still load with a warning; migrate to `GroupRoles.Policies` for forward compatibility.

<a id="step-9"></a>
## Step 9 — Apply changes (remove -WhatIf)

> **Safety Note:** By default the orchestrator operates in **delta** mode. That means it will create or update the assignments/policies you declare but it will **not delete** existing assignments that are absent from the config. Only new (or changed) items are acted on, so there is no risk of breaking existing access at this step. Destructive cleanup requires explicitly running Step 13 with `-Mode initial` (and ideally a prior `-WhatIf`).

Apply policies

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -SkipAssignments
```

Apply assignments

```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -SkipPolicies
```

<a id="step-10"></a>
## Step 10 — Use the Same Config from Azure Key Vault (Optional)

Centralize the orchestrator configuration by storing the exact JSON in an Azure Key Vault secret.

1. Create / select Key Vault (one-time):
  ```powershell
  az keyvault create -n <kv-name> -g <resource-group>
  ```
2. Upload JSON (plain text file):
  ```powershell
  az keyvault secret set --vault-name <kv-name> --name EasyPIM-Config --file C:\Config\pim-config.json
  ```
3. Preview assignments (skip policies already applied):
  ```powershell
  Invoke-EasyPIMOrchestrator -KeyVaultName <kv-name> -SecretName EasyPIM-Config -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipPolicies
  ```
4. Apply:
  ```powershell
  Invoke-EasyPIMOrchestrator -KeyVaultName <kv-name> -SecretName EasyPIM-Config -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -SkipPolicies
  ```

Notes:
- Same schema as file; no transformation.
- Rotate by overwriting secret; callers just rerun.
- Keep size within Key Vault secret limits.
- CI: assign managed identity secret get permission.

Troubleshooting:
- Truncated/invalid: ensure plain UTF-8, no BOM, not base64.
- Access denied: verify RBAC/Access Policy includes get secret.
- Parse error: `az keyvault secret show --vault-name <kv-name> --name EasyPIM-Config --query value -o tsv | ConvertFrom-Json`.

<a id="step-11"></a>
## Step 11 — (Optional, Destructive) Reconcile with initial mode
> **Pre-Execution Backup Recommended:** Step 0 only backed up policies. Before running a destructive initial reconcile you should also snapshot CURRENT assignments so you can restore or justify removals. Export (or at least list to CSV) each assignment category:
> - Entra role eligible: `Get-PIMEntraRoleEligibleAssignment -tenantID <tenant>`
> - Entra role active: `Get-PIMEntraRoleActiveAssignment -tenantID <tenant>`
> - Azure role eligible: `Get-PIMAzureResourceEligibleAssignment -tenantID <tenant> -subscriptionID <sub>`
> - Azure role active: `Get-PIMAzureResourceActiveAssignment -tenantID <tenant> -subscriptionID <sub>`
> - (If used) Group eligible: `Get-PIMGroupEligibleAssignment -tenantID <tenant>`
> - (If used) Group active: `Get-PIMGroupActiveAssignment -tenantID <tenant>`
>
> Example quick export (PowerShell):
> ```powershell
> # Module updated: Get-*Assignment cmdlets now emit clean objects (no leading count string), so you can pipe directly.
> Get-PIMEntraRoleEligibleAssignment -tenantID $tid | Export-Csv -Path C:\Logs\EntraEligible-BeforeInitial.csv -NoTypeInformation
>
> Get-PIMEntraRoleActiveAssignment -tenantID $tid | Export-Csv -Path C:\Logs\EntraActive-BeforeInitial.csv -NoTypeInformation
>
> Get-PIMAzureResourceEligibleAssignment -tenantID $tid -subscriptionID $sub | Export-Csv -Path C:\Logs\AzureEligible-BeforeInitial.csv -NoTypeInformation
> ```
> Keep these artifacts with the WouldRemove export for audit / rollback.

Use this mode ONLY when you intend to remove every assignment not explicitly declared (except `ProtectedUsers`). Always run a -WhatIf preview first.
### What WOULD Be Removed? (-Mode initial -WhatIf example)

When you run an initial (destructive) reconcile with `-WhatIf`, the orchestrator enumerates everything it **would** delete so you can validate safely before executing. Preview this FIRST so you know the scale of change before reading further.

Illustrative sample output (truncated):

```text
───────────────────────────────────────────────────────────────────────────────┐
│ CLEANUP OPERATIONS
├───────────────────────────────────────────────────────────────────────────────┤
│ ✅ Kept    : 4
│ 🗑️ Removed : 0
│ 🛈 WouldRemove: 10
│    - AcrPull  /subscriptions/<sub-guid> f53bf02e-c703-40ab-b5cb-af0d546bc2c4
│    - Key Vault Secrets Officer /subscriptions/<sub-guid>/resourceGroups/RG-PIMTEST/providers/Microsoft.KeyVault/vaults/KVPIM 9f2aacfc-8c80-41a7-ba07-121e0cb29757
│    - Storage Blob Data Owner /subscriptions/<sub-guid>/resourceGroups/cloud-shell-storage-westeurope/providers/Microsoft.Storage/storageAccounts/devsample1 e54e29a4-5c6f-47a6-a5d7-7d555f77fb41
│    - Storage Blob Data Owner /subscriptions/<sub-guid>/resourceGroups/cloud-shell-storage-westeurope/providers/Microsoft.Storage/storageAccounts/devsample2 d2a829da-a0aa-4dab-9cee-a468285d101b
│    - Storage Queue Data Contributor /subscriptions/<sub-guid>/resourceGroups/cloud-shell-storage-westeurope/providers/Microsoft.Storage/storageAccounts/devsample1 e54e29a4-5c6f-47a6-a5d7-7d555f77fb41
│    ... (+5 more)
│ ⏭️ Skipped : 8
│ 🛡️ Protected: 10
└───────────────────────────────────────────────────────────────────────────────┘
```

Use the "Export the Full WouldRemove List" subsection below to capture the complete set for audit before proceeding.


Preview destructive reconcile:
```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -Mode initial -WhatIf -SkipPolicies
```



### Export the Full WouldRemove List (Audit / Peer Review)

You can export the complete set of preview removals for offline review or change‑control attachment using the new `-WouldRemoveExportPath` parameter.

Scenarios:
- Attach the JSON to a CAB / change ticket
- Diff two consecutive preview runs
- Manually whitelist unexpected principals before executing destructive mode

Usage (directory path – auto‑generates timestamped filename):
```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -Mode initial -WhatIf -WouldRemoveExportPath C:\Logs\PIMPreview
```
Result (example):
```
📤 Exported WouldRemove list (10 item(s)) to: C:\Logs\PIMPreview\EasyPIM-WouldRemove-20250811T134338.json
```

Usage (explicit file path – extension controls format):
```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -Mode initial -WhatIf -WouldRemoveExportPath C:\Logs\preview.csv
```
- If the path ends with `.csv` a CSV is produced; any other (or no) extension defaults to JSON.
- File is written even under `-WhatIf` (safe preview) so you always have an artifact.
- An empty export (`[]` or headers only) means no deletions are projected.

Sample JSON entry:
```json
{
  "PrincipalId": "f53bf02e-c703-40ab-b5cb-af0d546bc2c4",
  "PrincipalName": "Adam Warlock",
  "RoleName": "AcrPull",
  "Scope": "/subscriptions/<sub-guid>",
  "ResourceType": "Azure Role eligible",
  "Mode": "initial-preview"
}
```

Recommended review checklist before executing destructive apply:
1. Confirm every removal candidate is truly unintended or should be purged.
2. Verify no break‑glass / emergency accounts appear (if so add them to `ProtectedUsers`).
3. Re‑run preview until the export list matches expected deltas.
4. (Optional) Commit the export file to a secure audit repository.

Then proceed without `-WhatIf` when satisfied.

Legend / interpretation:

* Kept – Assignments declared in config (no action needed)
* Removed – Assignments actually removed in a non-`-WhatIf` destructive run (always 0 during preview)
* WouldRemove – Assignments NOT in config that would be deleted if you re-run without `-WhatIf`
  * The list shows the first few (role name, scope, principal objectId). Full list retained in memory.
* Skipped – Items intentionally ignored (e.g., unsupported type, already compliant, or safety exclusions)
* Protected – Assignments whose principals are in `ProtectedUsers` (never removed)

Checklist before removing `-WhatIf`:
1. Review every WouldRemove entry – confirm each is genuinely obsolete.
2. Add any missing but still required assignments to the config (they will then move from WouldRemove → Kept on the next preview).
3. Ensure all break‑glass / critical accounts are in `ProtectedUsers` (they'll appear under Protected, not WouldRemove).
4. (Optional) Capture this preview output for audit/change record.
5. Re-run the same command once more with `-WhatIf` to confirm no unexpected drift just before execution.

Then execute using the destructive command (without `-WhatIf`) only after you are satisfied.

> Delta mode note: In `delta` mode nothing is deleted; such items would instead surface as `WouldRemove (delta)` to keep you aware of potential cleanup candidates without any risk.

<div style="background:#ffecec;border:2px solid #ff4d4f;padding:16px;border-radius:6px;">
  <strong style="color:#d8000c;font-size:1.05em;">⚠️ DESTRUCTIVE MODE WARNING (Step 13)</strong>
  <ul style="margin-top:8px;">
    <li><strong>All assignments NOT declared in your config will be REMOVED</strong> (except principals listed under <code>ProtectedUsers</code>).</li>
    <li>Verify <code>ProtectedUsers</code> includes every break‑glass / critical account before proceeding.</li>
    <li>Review prior delta runs: investigate any <code>WouldRemove (delta)</code> items you are not expecting.</li>
  </ul>
  <p style="margin-top:8px;">
    <em>Best practice:</em> Run at least once with <code>-WhatIf</code>, capture the summary for audit, and (optionally) perform a fresh backup (top of Step 13) immediately before executing the destructive apply.
  </p>
</div>

<!-- Fallback (plain markdown) if HTML rendering is stripped:
**DESTRUCTIVE MODE WARNING (Step 13)**
* All assignments NOT declared in your config will be REMOVED (except ProtectedUsers).
* Verify ProtectedUsers contains every break-glass / critical account.
* Review prior delta runs for any unexpected `WouldRemove (delta)` entries.
* Run once with -WhatIf and take a backup first.
-->
Execute (destructive) ONLY after validating preview:
```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -Mode initial -SkipPolicies
```


---



<a id="step-12"></a>
## Step 12 — Comprehensive policy validation (all options)

This step validates that every major policy lever is understood and renders correctly: activation & eligibility durations, *active* vs *eligible* enablement rules, authentication context, approvers, permanent eligibility flags, and the full three‑phase notification matrix (Eligibility, Active, Activation). It also introduces a reusable template that captures all options.

### 14.0 Template + Override Pattern (Recommended Approach)

**Templates provide consistency and reduce repetition.** Define common security patterns once, then inherit and override specific properties as needed. This pattern works across all policy types (EntraRoles, AzureRoles, GroupRoles).

**How It Works:**
1. **Template Properties**: All properties from the referenced template are inherited
2. **Override Properties**: Any property specified alongside `"Template"` overrides the template value
3. **Scope Preservation**: For Azure roles, `Scope` must always be specified (not inherited from templates)
4. **Logical Consistency**: When `ApprovalRequired: true`, you MUST provide `Approvers` array

**Benefits:**
- **Consistency**: Ensure common security patterns across roles
- **Flexibility**: Customize individual roles without duplicating configurations
- **Maintainability**: Update templates to change multiple role policies at once
- **Clarity**: Explicit overrides make policy differences obvious

### Common Policy Fields Reference
Key fields you can configure (availability varies by resource type):
- **Duration Control**: `ActivationDuration`, `MaximumActiveAssignmentDuration`, `MaximumEligibilityDuration`
- **Security Requirements**: `ActivationRequirement`, `ActiveAssignmentRequirement` (enablement rules)
- **Approval Control**: `ApprovalRequired` + `Approvers` (array of objects with id + optional description)
- **Permanency Control**: `AllowPermanentEligibility`, `AllowPermanentActiveAssignment`
- **Conditional Access**: `AuthenticationContext_Enabled` + `AuthenticationContext_Value`
- **Communication**: `Notifications` (Eligibility / Active / Activation phases with Alert / Assignee / Approvers blocks)

### 14.1 Template + Override Examples
```jsonc
{
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"],
  "PolicyTemplates": {
    "StandardSecurity": {
      "ActivationDuration": "PT8H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": false,
      "MaximumEligibilityDuration": "P365D",
      "AllowPermanentEligibility": false
    },
    "HighSecurity": {
      "ActivationDuration": "PT4H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification,Ticketing",
      "ApprovalRequired": true,
      "Approvers": [
        { "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "description": "Security Admin 1" },
        { "id": "ffffffff-1111-2222-3333-444444444444", "description": "Security Team Group" }
      ],
      "MaximumEligibilityDuration": "P90D",
      "AllowPermanentEligibility": false,
      "AuthenticationContext_Enabled": true,
      "AuthenticationContext_Value": "c1:HighRiskOperations"
    },
    "AllOptions": {
      "ActivationDuration": "PT2H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification,Ticketing",
      "ActiveAssignmentRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": true,
      "Approvers": [
        { "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "description": "PIM Approver 1" },
        { "id": "ffffffff-1111-2222-3333-444444444444", "description": "Approver Group" }
      ],
      "AllowPermanentEligibility": false,
      "AllowPermanentActiveAssignment": false,
      "MaximumEligibilityDuration": "P180D",
      "MaximumActiveAssignmentDuration": "P30D",
      "AuthenticationContext_Enabled": true,
      "AuthenticationContext_Value": "c1:HighRiskOperations",
      "Notifications": {
        "Eligibility": {
          "Alert": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
          "Assignee":  { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
          "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
        },
        "Active": {
          "Alert": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
          "Assignee":  { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
          "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
        },
        "Activation": {
          "Alert": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-alerts@contoso.com"] },
          "Assignee":  { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-assignees@contoso.com"] },
          "Approvers": { "isDefaultRecipientEnabled": true, "NotificationLevel": "All", "Recipients": ["pim-approvers@contoso.com"] }
        }
      }
    }
  },

  // Template inheritance examples across all policy types
  "EntraRoles": {
    "Policies": {
      // Template only - uses all StandardSecurity settings
      "User Administrator": {
        "Template": "StandardSecurity"
      },
      // Template + override - inherits StandardSecurity but with custom duration
      "Exchange Administrator": {
        "Template": "StandardSecurity",
        "MaximumEligibilityDuration": "P180D"
      },
      // Template + approval override - adds approval to StandardSecurity template
      "Security Administrator": {
        "Template": "StandardSecurity",
        "ApprovalRequired": true,
        "Approvers": [
          { "id": "security-team@contoso.com", "description": "Security Team" }
        ]
      },
      // High security template for critical roles
      "Global Administrator": {
        "Template": "HighSecurity",
        "MaximumEligibilityDuration": "P30D"  // Even shorter for Global Admin
      }
    }
  },

  "AzureRoles": {
    "Policies": {
      // Template + scope override (Scope is ALWAYS required for Azure roles)
      "Contributor": {
        "Template": "StandardSecurity",
        "Scope": "/subscriptions/<sub-guid>",
        "ActivationDuration": "PT12H"  // Override for longer Azure access
      },
      // High security for critical Azure roles
      "Owner": {
        "Template": "HighSecurity",
        "Scope": "/subscriptions/<sub-guid>",
        "MaximumEligibilityDuration": "P60D"  // Even shorter for Owner role
      },
      // Resource group specific override
      "Storage Account Contributor": {
        "Template": "StandardSecurity",
        "Scope": "/subscriptions/<sub-guid>/resourceGroups/rg-production",
        "ApprovalRequired": true,
        "Approvers": [
          { "id": "storage-admins@contoso.com", "description": "Storage Team" }
        ]
      }
    }
  },

  "GroupRoles": {
    "Policies": {
      // Template inheritance works for group roles too
      "f47ac10b-58cc-4372-a567-0e02b2c3d479": {
        "Owner": {
          "Template": "StandardSecurity",
          "ActivationRequirement": "Justification"  // Remove MFA for group ownership
        },
        "Member": {
          "Template": "StandardSecurity",
          "ApprovalRequired": true,
          "Approvers": [
            { "id": "group-managers@contoso.com", "description": "Group Managers" }
          ]
        }
      }
    }
  }
}
```

**Preview template + override policies:**
```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf -SkipAssignments
```

### 14.2 Inline Policy Examples (Alternative Approach)
For cases where templates don't fit your needs, you can define policies inline. Use this approach sparingly to avoid configuration drift.

**Entra Role Example (inline):**
```jsonc
{
  "ProtectedUsers": ["00000000-0000-0000-0000-000000000001"],
  "EntraRoles": {
    "Policies": {
      "User Administrator": {
        "ActivationDuration": "PT2H",
        "ActivationRequirement": "MultiFactorAuthentication,Justification",
        "ApprovalRequired": true,
        "Approvers": [
          { "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "description": "Security Team Lead" }
        ],
        "MaximumEligibilityDuration": "P180D"
      }
    }
  }
}
```

**Azure Role Example (inline):**
```jsonc
{
  "AzureRoles": {
    "Policies": {
      "Contributor": {
        "Scope": "/subscriptions/<sub-guid>",
        "ActivationDuration": "PT4H",
        "ActivationRequirement": "MultiFactorAuthentication,Justification",
        "ApprovalRequired": true,
        "Approvers": [
          { "id": "azure-admins@contoso.com", "description": "Azure Administrators" }
        ],
        "MaximumEligibilityDuration": "P180D"
      }
    }
  }
}
```

**Group Role Example (inline):**
```jsonc
{
  "GroupRoles": {
    "Policies": {
      "<group-object-id>": {
        "Member": {
          "ActivationDuration": "PT4H",
          "ActivationRequirement": ["Justification"],
          "ApprovalRequired": true,
          "Approvers": [
            { "id": "group-owners@contoso.com", "description": "Group Owners" }
          ],
          "MaximumEligibilityDuration": "P180D"
        }
      }
    }
  }
}
```

> **⚠️ Important:** When `ApprovalRequired: true`, you MUST include the `Approvers` array. The system will reject policies that require approval without specifying who can approve.

### 14.3 Full Options Reference (AllOptions Template)

For comprehensive policy configurations that use every available feature, reference the `AllOptions` template shown in section 12.1. This template demonstrates all available policy fields including:

- **Duration Controls**: Activation, eligibility, and active assignment time limits
- **Security Requirements**: MFA, justification, ticketing for both activation and permanent assignment
- **Approval Workflows**: Approval requirements with proper approver configurations
- **Conditional Access**: Authentication context integration for high-risk operations
- **Communication**: Full notification matrix for all assignment lifecycle phases
- **Permanency Controls**: Flags to control permanent eligibility and active assignments

**Critical Validation Rules:**
- `ApprovalRequired: true` MUST include `Approvers` array with at least one approver
- Azure role policies MUST include `Scope` (cannot be inherited from templates)
- `AuthenticationContext_*` settings are ignored for Group policies (use shared templates safely)
- `ActivationRequirement` and `ActiveAssignmentRequirement` values are case-sensitive, comma-separated

**Example AllOptions Template Usage:**
```jsonc
{
  "PolicyTemplates": {
    "AllOptions": { /* see section 12.1 for full definition */ }
  },
  "EntraRoles": {
    "Policies": {
      "Global Administrator": {
        "Template": "AllOptions",
        "MaximumEligibilityDuration": "P30D"  // Override for even stricter Global Admin
      }
    }
  }
}
```

### Notes
* ActivationRequirement & ActiveAssignmentRequirement values are case‑sensitive and comma separated (avoid spaces unless inside list items array form).
* Approvers only used when ApprovalRequired = true.
* AuthenticationContext_* (if enabled) requires the referenced auth context to exist.
* AuthenticationContext_* is ignored for Group policies; you can keep it in shared templates, but it won’t be applied to Groups.
* Use Verify-PIMPolicies.ps1 or Test-PIMPolicyDrift to audit drift after applying.
* Keep templates minimal; AllOptions is illustrative — real production templates often exclude rarely used features.

<a id="step-13"></a>
## Step 13 — Detect policy drift with Test-PIMPolicyDrift

Goal: Verify that live policies match your declared configuration and catch out-of-band changes. Run this after Step 12 and after any apply to ensure compliance.

**Note:** `Test-PIMPolicyDrift` is provided by the `EasyPIM.Orchestrator` module.

What this does:
- Compares effective Entra/Azure role policies to your JSON-defined expectations
- Highlights differences per rule (enablement, durations, notifications, approvals, authentication context)
- Works in non-destructive mode; ideal for scheduled audits

Minimal usage (file config):
```powershell
Test-PIMPolicyDrift -ConfigFilePath "C:\Config\pim-config.json" -TenantId $env:TENANTID -SubscriptionId $env:SUBSCRIPTIONID
```

Key Vault usage:
```powershell
Test-PIMPolicyDrift -KeyVaultName MyPIMVault -SecretName PIMConfig -TenantId $env:TENANTID -SubscriptionId $env:SUBSCRIPTIONID
```

Options and tips:
- Use -PolicyOperations to limit domains (e.g., EntraRoles only)
- Use -OutputPath C:\Logs to export a timestamped JSON/CSV report for review
- Pair with your pipeline to fail builds on detected drift
- If Authentication Context is enabled, expect MFA to be absent from EndUser enablement by design

Next: If drift is found, re-run Step 2/3/6/7 policy previews with -WhatIf to confirm the intended state, then apply.

---

<a id="step-14"></a>
## Step 14 — (Optional) CI/CD automation (GitHub Actions + Key Vault)

Reality check (Key Vault change triggers): GitHub Actions cannot natively subscribe to Key Vault secret change events. To be truly event‑driven you need an Azure component (Event Grid -> Logic App / Azure Function) that calls the GitHub REST API (repository_dispatch) or invokes an Azure DevOps pipeline. Below we give (1) a pragmatic scheduled/on‑demand workflow and (2) an advanced event pattern outline.

- **Event-driven orchestration pattern:**
    - Use Azure Event Grid to subscribe to Key Vault secret change events.
    - Trigger a Logic App or Azure Function when a config secret changes.
    - The Logic App/Azure Function can call the GitHub REST API (`repository_dispatch`) to trigger a workflow, or invoke an Azure DevOps pipeline.
    - This enables automatic orchestration runs whenever your config changes, without manual intervention.
    - For advanced patterns, see the dedicated repo and Azure docs for Event Grid integration.

**EasyPIM CI/CD and pipeline setup is now maintained in a dedicated repository:**

👉 **Please use [EasyPIM-CICD-test](https://github.com/kayasax/EasyPIM-CICD-test) for all GitHub Actions, Key Vault integration, and automated orchestration setup.**

This repo contains:
- End-to-end pipeline examples
- OIDC setup and federated credential instructions
- Permission matrix and safety patterns
- Promotion and drift gate workflows
- Observability and failure handling best practices

All future updates, bugfixes, and advanced patterns will be published there. This guide will only reference the external repo for CI/CD automation.

For details, see: https://github.com/kayasax/EasyPIM-CICD-test

<a id="appendix"></a>
## Appendix: Tips & Safety Gates

### Automatic Principal Validation (Safety Gate)
The orchestrator now ALWAYS validates all referenced principals (users, groups, service principals) and role‑assignable status for groups before any changes. If issues are detected it aborts before policies or assignments are processed.

**Benefits:**
- Prevents misleading "Created" outputs caused by placeholder GUIDs.
- Catches non role‑assignable groups before assignment attempts.
- Produces a concise invalid principal summary without touching assignments or policies.

If validation fails:
1. Replace placeholder or removed object IDs with real ones.
2. (Optional) For groups: if you plan classic privileged directory role use outside this orchestrator, you may still choose to set them role-assignable; it's not required for orchestrator processing.
3. Remove or comment obsolete principals, then re-run.

If you genuinely need to ignore a transient missing ID, temporarily comment it out (future enhancement may add an override switch).

### Verification Tips

- ActivationRequirement values are case-sensitive: `None`, `MultiFactorAuthentication`, `Justification`, `Ticketing` (combine with commas)
- Azure policies require `Scope`; Entra policies are directory-wide
- AU-scoped Entra cleanup isn’t automatic; remove manually if needed
- Keep break-glass accounts in `ProtectedUsers` at all times

### References

- See `EasyPIM-Orchestrator-Complete-Tutorial.md` for end-to-end context
- See `Configuration-Schema.md` for the full schema and field definitions
