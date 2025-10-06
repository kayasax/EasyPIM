# PIM for Groups - Array Format Configuration

## Overview

The EasyPIM Orchestrator supports array-based configuration for PIM for Groups policies starting with version 1.1. This format provides a consistent structure across all policy types (Azure roles, Entra roles, and Groups) and enables more flexible policy management.

## Array Format Structure

### Groups.Policies Array

The `Groups.Policies` property can be an array where each element contains:

- `GroupId` (required) - Azure AD Group Object ID (GUID)
- `RoleName` (required) - Group role: "Member" or "Owner"
- `Template` (optional) - Reference to a policy template
- `PolicySource` (optional) - Either "template" or "inline"
- Additional policy properties (overrides or inline policy settings)

### Template-Based Policy Example

```json
{
  "Groups": {
    "Policies": [
      {
        "GroupId": "12345678-1234-1234-1234-123456789012",
        "RoleName": "Member",
        "Template": "Tier0_Critical_Groups",
        "PolicySource": "template"
      },
      {
        "GroupId": "12345678-1234-1234-1234-123456789012",
        "RoleName": "Owner",
        "Template": "Tier1_High_Groups",
        "PolicySource": "template"
      }
    ]
  }
}
```

### Template with Overrides Example

```json
{
  "Groups": {
    "Policies": [
      {
        "GroupId": "87654321-4321-4321-4321-210987654321",
        "RoleName": "Member",
        "Template": "Tier1_High_Groups",
        "PolicySource": "template",
        "ActivationDuration": "PT4H",
        "ApprovalRequired": true
      }
    ]
  }
}
```

### Inline Policy Example

```json
{
  "Groups": {
    "Policies": [
      {
        "GroupId": "abcdef12-3456-7890-abcd-ef1234567890",
        "RoleName": "Member",
        "PolicySource": "inline",
        "Policy": {
          "ActivationDuration": "PT2H",
          "ApprovalRequired": true,
          "Approvers": [
            {
              "Id": "user@example.com",
              "Type": "user"
            }
          ]
        }
      }
    ]
  }
}
```

### Flattened Inline Policy Example

```json
{
  "Groups": {
    "Policies": [
      {
        "GroupId": "fedcba09-8765-4321-fedc-ba0987654321",
        "RoleName": "Owner",
        "PolicySource": "inline",
        "ActivationDuration": "PT8H",
        "ApprovalRequired": false
      }
    ]
  }
}
```

## Role-Specific Policies

Unlike Entra roles, Groups support two distinct roles:
- **Member** - Policies for group membership assignment
- **Owner** - Policies for group ownership assignment

You can define different policies for each role within the same group:

```json
{
  "Groups": {
    "Policies": [
      {
        "GroupId": "12345678-1234-1234-1234-123456789012",
        "RoleName": "Member",
        "Template": "Tier1_High_Groups",
        "ActivationDuration": "PT2H"
      },
      {
        "GroupId": "12345678-1234-1234-1234-123456789012",
        "RoleName": "Owner",
        "Template": "Tier0_Critical_Groups",
        "ActivationDuration": "PT1H",
        "ApprovalRequired": true
      }
    ]
  }
}
```

## Backward Compatibility

The orchestrator also supports the legacy object format:

```json
{
  "Groups": {
    "Policies": {
      "12345678-1234-1234-1234-123456789012": {
        "Member": {
          "Template": "Tier1_High_Groups"
        },
        "Owner": {
          "Template": "Tier0_Critical_Groups"
        }
      }
    }
  }
}
```

**Important**: You cannot mix array and object formats in the same configuration. The orchestrator will throw an error if both `Groups.Policies` (array) and legacy object format are detected simultaneously.

## Configuration Validation

The orchestrator validates Groups array configurations for:

1. **Required Properties**
   - `GroupId` must be present and valid
   - `RoleName` must be present and one of: "Member", "Owner"

2. **Template References**
   - If `Template` is specified, it must exist in `PolicyTemplates`

3. **Approvers Format**
   - If `ApprovalRequired` is true and policy is inline, `Approvers` array must be present
   - Approvers must have valid structure with `Id` and `Type` properties

4. **Conflict Detection**
   - Only one format (array or object) can be present
   - Duplicate entries (same GroupId + RoleName combination) are not allowed

## Policy Processing

The orchestrator processes Groups array policies through:

1. **Initialize-EasyPIMPolicies** - Parses and validates the configuration
2. **Resolve-PolicyConfiguration** - Applies templates and merges overrides
3. **New-EPOEasyPIMPolicies** - Orchestrates policy application
4. **Set-EPOGroupPolicy** - Applies individual group policies via Microsoft Graph API

## Testing

The orchestrator includes comprehensive Pester tests for Groups array format:
- Template-based policies with overrides
- Inline policies (nested and flattened)
- Multiple groups and roles
- Backward compatibility with object format
- Error handling for missing required properties

Run tests with:
```powershell
pwsh -File tests/pester.ps1
```

## See Also

- [Azure Role Policies Array Format](Azure-Role-Policies-Array.md)
- [Entra Role Policies Array Format](Entra-Role-Policies-Array.md)
- [Enhanced Orchestrator Policy Design](Development/Enhanced-Orchestrator-Policy-Design.md)
