# Enhanced EasyPIM Orchestrator - Policy Management Usage Guide

## Overview

The enhanced `Invoke-EasyPIMOrchestrator` now supports comprehensive policy management alongside assignment management. This allows you to define and apply PIM policies declaratively through JSON configuration.

## New Features

### 🆕 Policy Management Support
- **Azure Role Policies**: Configure PIM policies for Azure RBAC roles
- **Entra Role Policies**: Configure PIM policies for Entra ID directory roles
- **Group Policies**: Configure PIM policies for Group role assignments
- **Policy Templates**: Define reusable policy configurations
- **Multiple Policy Sources**: Support for inline, file, and template-based policies

### 🆕 New Parameters

```powershell
# Skip policy processing entirely
-SkipPolicies

# Control which policy types to process
-PolicyOperations @("All"|"AzureRoles"|"EntraRoles"|"GroupRoles")

# Control policy application mode
-PolicyMode ("validate"|"delta"|"initial")
```

## Configuration Schema

### Policy Sections

#### Azure Role Policies
```json
"AzureRolePolicies": [
    {
        "RoleName": "Owner",
        "Scope": "/subscriptions/subscription-id",
        "PolicySource": "inline",
        "Policy": {
            "ActivationDuration": "PT8H",
            "EnablementRules": ["MultiFactorAuthentication", "Justification"],
            "ApprovalRequired": true,
            "Approvers": [
                {
                    "id": "group-id",
                    "description": "Security Team",
                    "userType": "Group"
                }
            ],
            "AllowPermanentEligibleAssignment": false,
            "MaximumEligibleAssignmentDuration": "P90D"
        }
    }
]
```

#### Entra Role Policies
```json
"EntraRolePolicies": [
    {
        "RoleName": "Security Reader",
        "PolicySource": "template",
        "PolicyTemplate": "Standard"
    }
]
```

#### Group Policies
```json
"GroupPolicies": [
    {
        "GroupId": "group-id",
        "RoleName": "Owner",
        "PolicySource": "template",
        "PolicyTemplate": "HighSecurity"
    }
]
```

#### Policy Templates
```json
"PolicyTemplates": {
    "HighSecurity": {
        "ActivationDuration": "PT2H",
        "EnablementRules": ["MultiFactorAuthentication", "Justification"],
        "ApprovalRequired": true,
        "AllowPermanentEligibleAssignment": false,
        "MaximumEligibleAssignmentDuration": "P30D"
    },
    "Standard": {
        "ActivationDuration": "PT8H",
        "EnablementRules": ["MultiFactorAuthentication"],
        "ApprovalRequired": false,
        "AllowPermanentEligibleAssignment": true,
        "MaximumEligibleAssignmentDuration": "P90D"
    }
}
```

## Policy Sources

### 1. Inline Policies
Define policies directly in the JSON configuration:
```json
{
    "PolicySource": "inline",
    "Policy": {
        "ActivationDuration": "PT8H",
        "EnablementRules": ["MultiFactorAuthentication"]
    }
}
```

### 2. Template Policies
Reference predefined templates:
```json
{
    "PolicySource": "template",
    "PolicyTemplate": "HighSecurity"
}
```

### 3. File Policies
Reference existing CSV policy exports:
```json
{
    "PolicySource": "file",
    "PolicyFile": "C:\\path\\to\\policy.csv"
}
```

## Policy Modes

### Validate Mode (Default)
- Validates configuration without applying changes
- Reports what would be changed
- Safe for testing configurations

### Delta Mode
- Applies only policies that differ from current state
- Compares with existing policies
- Recommended for production updates

### Initial Mode
- Applies all defined policies
- Overwrites existing policies
- Use for full policy deployment

## Usage Examples

### Example 1: Validate Policy Configuration
```powershell
Invoke-EasyPIMOrchestrator `
    -ConfigFilePath "C:\config\enhanced-config.json" `
    -TenantId "your-tenant-id" `
    -SubscriptionId "your-subscription-id" `
    -PolicyMode "validate" `
    -SkipAssignments `
    -SkipCleanup
```

### Example 2: Apply Only Azure Role Policies
```powershell
Invoke-EasyPIMOrchestrator `
    -ConfigFilePath "C:\config\enhanced-config.json" `
    -TenantId "your-tenant-id" `
    -SubscriptionId "your-subscription-id" `
    -PolicyOperations @("AzureRoles") `
    -PolicyMode "delta" `
    -SkipAssignments
```

### Example 3: Full Orchestration with Policies
```powershell
Invoke-EasyPIMOrchestrator `
    -ConfigFilePath "C:\config\enhanced-config.json" `
    -TenantId "your-tenant-id" `
    -SubscriptionId "your-subscription-id" `
    -Mode "delta" `
    -PolicyMode "delta"
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
- `EnablementRules`: Array of required actions (MFA, Justification, Ticketing)
- `ApprovalRequired`: Whether activation requires approval
- `Approvers`: Array of approver objects

### Assignment Duration Settings
- `AllowPermanentEligibleAssignment`: Allow permanent eligible assignments
- `MaximumEligibleAssignmentDuration`: Maximum duration for eligible assignments
- `AllowPermanentActiveAssignment`: Allow permanent active assignments
- `MaximumActiveAssignmentDuration`: Maximum duration for active assignments

### Notification Settings
Configure notifications for different events:
- `Eligibility`: Notifications for eligibility changes
- `Active`: Notifications for active assignment changes
- `Activation`: Notifications for role activations

Each notification type supports:
- `Alert`: Admin notifications
- `Assignee`: User notifications
- `Approvers`: Approver notifications

## Best Practices

### 1. Start with Validation
Always test configurations in validation mode first:
```powershell
-PolicyMode "validate"
```

### 2. Use Policy Templates
Create reusable templates for consistent policy application:
```json
"PolicyTemplates": {
    "HighPrivilege": { /* high security settings */ },
    "Standard": { /* standard settings */ },
    "ReadOnly": { /* minimal requirements */ }
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
2. Test with `-PolicyMode "validate"`
3. Apply with `-PolicyMode "delta"`

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
