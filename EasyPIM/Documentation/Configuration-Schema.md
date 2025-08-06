# EasyPIM Configuration Schema

## Overview
This document defines the complete schema for EasyPIM configuration files, including both policy management and assignment orchestration.

## Root Configuration Object

```json
{
  "PolicyTemplates": { /* Policy Templates Object */ },
  "EntraRoles": { /* Entra Roles Configuration */ },
  "AzureRoles": { /* Azure Roles Configuration */ },
  "Groups": { /* Groups Configuration */ },
  "Assignments": { /* Assignments Configuration */ }
}
```

## Policy Templates

Policy templates allow reusable policy configurations across multiple roles.

```json
{
  "PolicyTemplates": {
    "TemplateName": {
      "ActivationDuration": "string (ISO 8601 duration, e.g., 'PT2H')",
      "ActivationRequirement": "string (comma-separated: 'MultiFactorAuthentication', 'Justification')",
      "ApprovalRequired": "boolean",
      "AllowPermanentEligibility": "boolean",
      "MaximumEligibilityDuration": "string (ISO 8601 duration, e.g., 'P30D')",
      "AllowPermanentActiveAssignment": "boolean",
      "MaximumActiveAssignmentDuration": "string (ISO 8601 duration)",
      "Approvers": [
        {
          "id": "string (Azure AD Object ID)",
          "description": "string (display name)"
        }
      ],
      "AuthenticationContext_Enabled": "boolean",
      "AuthenticationContext_Value": "string",
      "Notification_EligibleAssignment_Alert": {
        "isDefaultRecipientEnabled": "string ('true' or 'false')",
        "notificationLevel": "string ('All', 'Critical', etc.)",
        "Recipients": ["string (email addresses)"]
      }
    }
  }
}
```

## Entra Roles Configuration

### Policy Configuration
```json
{
  "EntraRoles": {
    "Policies": {
      "RoleName": {
        // Option 1: Use Template
        "Template": "string (template name from PolicyTemplates)",

        // Option 2: Inline Policy (all policy properties as above)
        "ActivationDuration": "string",
        "ActivationRequirement": "string",
        // ... other policy properties
      }
    }
  }
}
```

## Azure Roles Configuration

### Policy Configuration
```json
{
  "AzureRoles": {
    "Policies": {
      "RoleName": {
        "Scope": "string (required - Azure resource scope)",
        // Option 1: Use Template
        "Template": "string (template name from PolicyTemplates)",

        // Option 2: Inline Policy
        "ActivationDuration": "string",
        "ActivationRequirement": "string",
        // ... other policy properties
      }
    }
  }
}
```

## Groups Configuration

### Policy Configuration
```json
{
  "Groups": {
    "Policies": {
      "GroupId": {
        "RoleName": "string (required - role within the group)",
        // Option 1: Use Template
        "Template": "string (template name from PolicyTemplates)",

        // Option 2: Inline Policy
        "ActivationDuration": "string",
        "ActivationRequirement": "string",
        // ... other policy properties
      }
    }
  }
}
```

## Assignments Configuration

⚠️ **CRITICAL**: All assignments MUST use `principalId` (Azure AD Object ID), NOT `principalName` or email addresses.

### Assignments Schema
```json
{
  "Assignments": {
    "EntraRoles": [
      {
        "roleName": "string (required - exact role name)",
        "assignments": [
          {
            "principalId": "string (required - Azure AD Object ID, e.g., '12345678-1234-1234-1234-123456789012')",
            "principalType": "string (required - 'User', 'Group', or 'ServicePrincipal')",
            "assignmentType": "string (required - 'Eligible' or 'Active')",
            "duration": "string (required for Active assignments - ISO 8601 duration)",
            "justification": "string (optional - reason for assignment)"
          }
        ]
      }
    ],
    "AzureRoles": [
      {
        "roleName": "string (required - exact role name)",
        "scope": "string (required - Azure resource scope)",
        "assignments": [
          {
            "principalId": "string (required - Azure AD Object ID)",
            "principalType": "string (required - 'User', 'Group', or 'ServicePrincipal')",
            "assignmentType": "string (required - 'Eligible' or 'Active')",
            "duration": "string (required for Active assignments - ISO 8601 duration)",
            "justification": "string (optional - reason for assignment)"
          }
        ]
      }
    ],
    "Groups": [
      {
        "groupId": "string (required - Azure AD Group Object ID)",
        "roleName": "string (required - 'Owner' or 'Member')",
        "assignments": [
          {
            "principalId": "string (required - Azure AD Object ID)",
            "principalType": "string (required - 'User', 'Group', or 'ServicePrincipal')",
            "assignmentType": "string (required - 'Eligible' or 'Active')",
            "duration": "string (required for Active assignments - ISO 8601 duration)",
            "justification": "string (optional - reason for assignment)"
          }
        ]
      }
    ]
  }
}
```

## Common Data Types

### Duration Format (ISO 8601)
- **Hours**: `PT2H` (2 hours), `PT8H` (8 hours)
- **Days**: `P1D` (1 day), `P30D` (30 days)
- **Months**: `P1M` (1 month), `P6M` (6 months)
- **Years**: `P1Y` (1 year)

### Azure AD Object IDs
- **Format**: `12345678-1234-1234-1234-123456789012`
- **Source**: Azure AD portal, PowerShell (`Get-AzADUser`, `Get-AzADGroup`), Graph API
- **Never use**: Email addresses, display names, UPNs

### Azure Resource Scopes
- **Subscription**: `/subscriptions/{subscription-id}`
- **Resource Group**: `/subscriptions/{subscription-id}/resourceGroups/{rg-name}`
- **Resource**: `/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/{provider}/{resource}`

## Validation Rules

### Required Fields
1. **Policy Templates**: Template name, at least one policy property
2. **Policies**: Role name, either Template or inline policy properties
3. **Assignments**: roleName, principalId, principalType, assignmentType
4. **Azure Assignments**: Additional scope requirement
5. **Group Assignments**: Additional groupId requirement

### Data Validation
1. **principalId**: Must be valid GUID format
2. **duration**: Must be valid ISO 8601 duration
3. **assignmentType**: Must be 'Eligible' or 'Active'
4. **principalType**: Must be 'User', 'Group', or 'ServicePrincipal'

### Business Logic
1. **Active assignments**: MUST have duration specified
2. **Eligible assignments**: Duration is optional
3. **Azure role policies**: MUST have scope specified
4. **Template references**: Must exist in PolicyTemplates section

## Complete Example

```json
{
  "PolicyTemplates": {
    "StandardTemplate": {
      "ActivationDuration": "PT2H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": false,
      "AllowPermanentEligibility": false,
      "MaximumEligibilityDuration": "P30D"
    }
  },
  "EntraRoles": {
    "Policies": {
      "Security Reader": {
        "Template": "StandardTemplate"
      }
    }
  },
  "AzureRoles": {
    "Policies": {
      "Reader": {
        "Scope": "/subscriptions/12345678-1234-1234-1234-123456789012",
        "Template": "StandardTemplate"
      }
    }
  },
  "Assignments": {
    "EntraRoles": [
      {
        "roleName": "Security Reader",
        "assignments": [
          {
            "principalId": "87654321-4321-4321-4321-210987654321",
            "principalType": "User",
            "assignmentType": "Eligible",
            "justification": "Security team member"
          }
        ]
      }
    ],
    "AzureRoles": [
      {
        "roleName": "Reader",
        "scope": "/subscriptions/12345678-1234-1234-1234-123456789012",
        "assignments": [
          {
            "principalId": "87654321-4321-4321-4321-210987654321",
            "principalType": "User",
            "assignmentType": "Active",
            "duration": "PT8H",
            "justification": "Temporary access for project"
          }
        ]
      }
    ]
  }
}
```

## Migration Guide

### From principalName to principalId
1. **Find Object IDs**: Use `Get-AzADUser -UserPrincipalName "user@domain.com" | Select-Object Id`
2. **Update Configuration**: Replace `"principalName": "user@domain.com"` with `"principalId": "object-id"`
3. **Validate**: Ensure all principalId values are valid GUIDs

### Deprecated Formats
- ❌ `"principalName": "user@domain.com"`
- ❌ `"principalName": "Display Name"`
- ✅ `"principalId": "12345678-1234-1234-1234-123456789012"`

## Error Prevention
1. **Always reference this schema** when creating configurations
2. **Use Object IDs only** - never names or emails
3. **Validate JSON structure** before deployment
4. **Test with -WhatIf** parameter first
5. **Use templates** for consistent policy application
