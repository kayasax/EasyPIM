# Enhanced EasyPIM Orchestrator - Policy Management Usage Guide

## Overview

The enhanced `Invoke-EasyPIMOrchestrator` supports comprehensive policy management alongside assignment management. Define and validate PIM policies declaratively through JSON configuration.

## New Features

### 🆕 Policy Management Support
- **Azure Role Policies**: Configure PIM policies for Azure RBAC roles
- **Entra Role Policies**: Configure PIM policies for Entra ID directory roles
- **Group Policies**: Configure PIM policies for Group role assignments
- **Policy Templates**: Define reusable policy configurations
- **Multiple Policy Sources**: Support for inline, file, and template-based policies

### 🆕 Policy-related Parameters

```powershell
# Skip policy processing entirely
-SkipPolicies

# Control which policy types to process
-PolicyOperations @("All","AzureRoles","EntraRoles","GroupRoles")

# Use -WhatIf to validate policies without applying changes
-WhatIf
```

## Configuration Schema

### Policy Sections (current)

Policies live under each domain using a nested Policies block. Use either Template or inline properties.

#### Azure Role Policies (current)
NOTE: Built-in roles 'Owner' and 'User Access Administrator' are treated as protected by the orchestrator and their policies are skipped (reported as [PROTECTED]). Use a non-protected role such as 'Reader' or 'Contributor' in examples unless explicitly demonstrating the protection behavior.
```json
{
    "AzureRoles": {
        "Policies": {
            "Reader": {
                "Scope": "/subscriptions/subscription-id",
                "ActivationDuration": "PT8H",
                "ActivationRequirement": "MultiFactorAuthentication,Justification",
                "ApprovalRequired": true,
                "Approvers": [
                    { "id": "group-id", "description": "Security Team" }
                ],
                "AllowPermanentEligibility": false,
                "MaximumEligibilityDuration": "P90D"
            }
        }
    }
}
```

Template-based example:

```json
{
    "AzureRoles": {
        "Policies": {
            "Contributor": {
                "Scope": "/subscriptions/subscription-id",
                "Template": "Standard"
            }
        }
    }
}
```

#### Entra Role Policies (current)
```json
{
    "EntraRoles": {
        "Policies": {
            "Security Reader": { "Template": "Standard" },
            "User Administrator": {
                "ActivationDuration": "PT2H",
                "ActivationRequirement": "MultiFactorAuthentication,Justification",
                "ApprovalRequired": true
            }
        }
    }
}
```

#### Group Policies (current)
Note: Applying group policies is currently limited (validate-only/pending implementation). Include GroupId and RoleName in the policy definition.

```json
{
    "GroupRoles": {
        "Policies": {
            "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee": {
                "GroupId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                "RoleName": "Member",
                "Template": "Standard"
            }
        }
    }
}
```

#### Policy Templates (current)
```json
"PolicyTemplates": {
    "HighSecurity": {
        "ActivationDuration": "PT2H",
        "ActivationRequirement": "MultiFactorAuthentication,Justification",
        "ApprovalRequired": true,
        "Approvers": [
            {
                "id": "5dba24e0-00ef-4c21-9702-7c093a0775eb",
                "description": "Security Team",

            }
        ],
        "AllowPermanentEligibility": false,
        "MaximumEligibilityDuration": "P30D",
        "Notification_EligibleAssignment_Alert": {
            "isDefaultRecipientEnabled": true,
            "notificationLevel": "All",
            "Recipients": ["security-team@company.com"]
        }
    },
    "Standard": {
        "ActivationDuration": "PT8H",
        "ActivationRequirement": "MultiFactorAuthentication",
        "ApprovalRequired": false,
        "Approvers": [],
        "AllowPermanentEligibility": true,
        "MaximumEligibilityDuration": "P90D"
    },
    "ExecutiveApproval": {
        "ActivationDuration": "PT4H",
        "ActivationRequirement": "MultiFactorAuthentication,Justification",
        "ApprovalRequired": true,
        "Approvers": [
            {
                "id": "7a55ec4d-028e-4ff1-8ee9-93da07b6d5d5",
                "description": "Executive Team",

            }
        ],
        "AllowPermanentEligibility": false,
        "MaximumEligibilityDuration": "P7D"
    }
}
```

## Policy Sources

### 1. Inline Policies (current)
Define policies directly in the JSON configuration:
```json
{
    "EntraRoles": {
        "Policies": {
            "Security Administrator": {
                "ActivationDuration": "PT8H",
                "ActivationRequirement": "MultiFactorAuthentication",
                "ApprovalRequired": false
            }
        }
    }
}
```

### 2. Template Policies (current)
Reference predefined templates:
```json
{
    "AzureRoles": {
        "Policies": {
            "Owner": { "Scope": "/subscriptions/sub-id", "Template": "HighSecurity" }
        }
    }
}
```

### 3. File Policies (legacy, deprecated path)
Reference existing CSV policy exports using the legacy section:
```json
{
    "AzureRolePolicies": [
        {
            "RoleName": "Owner",
            "Scope": "/subscriptions/sub-id",
            "PolicySource": "file",
            "PolicyFile": "C:\\path\\to\\policy.csv"
        }
    ]
}
```

## Policy Execution Semantics

- Use `-WhatIf` to validate policy changes (no writes).
- Without `-WhatIf`, policies run in delta mode (apply differences).
- There is no dedicated `-PolicyMode` parameter.

## Usage Examples

### Example 1: Validate Policy Configuration
```powershell
Invoke-EasyPIMOrchestrator `
    -ConfigFilePath "C:\config\enhanced-config.json" `
    -TenantId "your-tenant-id" `
    -SubscriptionId "your-subscription-id" `
    -SkipAssignments `
    -SkipCleanup `
    -WhatIf
```

### Example 2: Apply Only Azure Role Policies
```powershell
Invoke-EasyPIMOrchestrator `
    -ConfigFilePath "C:\config\enhanced-config.json" `
    -TenantId "your-tenant-id" `
    -SubscriptionId "your-subscription-id" `
    -PolicyOperations @("AzureRoles") `
    -SkipAssignments
```

### Example 3: Full Orchestration with Policies
```powershell
Invoke-EasyPIMOrchestrator `
    -ConfigFilePath "C:\config\enhanced-config.json" `
    -TenantId "your-tenant-id" `
    -SubscriptionId "your-subscription-id"
```

### Example 4: Skip Policies, Process Only Assignments
```powershell
Invoke-EasyPIMOrchestrator `
    -ConfigFilePath "C:\config\enhanced-config.json" `
    -TenantId "your-tenant-id" `
    -SubscriptionId "your-subscription-id" `
    -SkipPolicies
```

## Policy Configuration Properties

### Core Policy Settings
- `ActivationDuration`: How long activations last (ISO 8601 duration)
- `ActivationRequirement`: Comma-separated requirements (e.g., "MultiFactorAuthentication,Justification")
- `ApprovalRequired`: Whether activation requires approval
- `Approvers`: Array of approver objects

### Assignment Duration Settings
- `AllowPermanentEligibility`: Allow permanent eligible assignments
- `MaximumEligibilityDuration`: Maximum duration for eligible assignments
- `AllowPermanentActiveAssignment`: Allow permanent active assignments
- `MaximumActiveAssignmentDuration`: Maximum duration for active assignments

### Notification Settings
Configure notifications using named blocks (examples):
- `Notification_EligibleAssignment_Alert`
- `Notification_EligibleAssignment_Assignee`
- `Notification_EligibleAssignment_Approver`
- `Notification_ActiveAssignment_Alert`
- `Notification_Activation_Alert`

### Approver Configuration
Define approvers for policy templates and inline policies:

```json
"Approvers": [
    {
        "id": "group-or-user-id",
        "description": "Human-readable description",

    }
]
```

**Approver Types:**
- **Group**: Azure AD/Entra ID security group (recommended)
- **User**: Individual user account

**Best Practices for Approvers:**
- Use groups instead of individual users for easier management
- Include backup approvers to avoid single points of failure
- Use descriptive names for easy identification
- Consider time zones when selecting approvers

## Best Practices

### 1. Start with Validation
Always test configurations in validation mode first:
```powershell
Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\\Config\\pim-config.json" -TenantId "<tenant-guid>" -SubscriptionId "<sub-guid>" -WhatIf
```

### 2. Use Policy Templates
Create reusable templates for consistent policy application:
```json
"PolicyTemplates": {
    "HighPrivilege": {
        "ActivationDuration": "PT2H",
    "ActivationRequirement": "MultiFactorAuthentication,Justification",
        "ApprovalRequired": true,
        "Approvers": [
            {
                "id": "security-team-group-id",
                "description": "Security Team",

            }
        ]
    },
    "Standard": {
        "ActivationDuration": "PT8H",
    "ActivationRequirement": "MultiFactorAuthentication",
        "ApprovalRequired": false,
        "Approvers": []
    },
    "ExecutiveLevel": {
        "ActivationDuration": "PT4H",
    "ActivationRequirement": "MultiFactorAuthentication,Justification",
        "ApprovalRequired": true,
        "Approvers": [
            {
        "id": "executive-team-group-id",
        "description": "Executive Team",

            }
        ],
        "Notifications": {
            "Activation": {
                "Alert": {
                    "Recipients": ["executives@company.com", "security@company.com"]
                }
            }
        }
    }
}
```

### 3. Separate Policy and Assignment Operations
Use dedicated runs for policies vs assignments:
```powershell
# Apply policies first
-SkipAssignments -SkipCleanup

# Then apply assignments
-SkipPolicies
```

### 4. Backup Before Changes
Export current policies before applying new ones:
```powershell
Export-PIMEntraRolePolicy -tenantID $tenantId -rolename @("Global Admin") -path "backup.csv"
```

### 5. Use WhatIf for Safety
Test with WhatIf to see what would change:
```powershell
-WhatIf
```

## Troubleshooting

### Common Issues

1. **Policy file not found**
   - Verify file paths in configuration
   - Use absolute paths

2. **Template not found**
   - Check template names match exactly
   - Verify PolicyTemplates section exists

3. **Invalid policy properties**
   - Check ISO 8601 duration format
   - Verify enablement rule names

### Debugging Tips

1. Use `-Verbose` for detailed output
2. Start with validation mode
3. Test individual policy sections
4. Check existing policy exports for reference

## Migration from Assignment-Only

Existing configurations continue to work unchanged. To add policies:

1. Add policy sections to your JSON
2. Validate with `-WhatIf`
3. Apply (delta is default when not using `-WhatIf`)

## Security Considerations

- Policies affect privileged access controls
- Test thoroughly in non-production environments
- Use approval requirements for high-privilege roles
- Monitor policy changes through audit logs
- Consider MFA requirements for policy modifications

---

**Version**: Enhanced Orchestrator v2.0
**Branch**: feature/orchestrator-policy-management
**Status**: ✅ Ready for Production Use
