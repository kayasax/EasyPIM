# Entra Role Policies Array Format

EasyPIM Orchestrator supports two configuration formats for Entra role policies:
1. **Array format** (recommended for new configurations)
2. **Object/dictionary format** (legacy, still supported)

## Array Format

The array format provides flexibility for managing policies from multiple sources and aligns with the Azure role policies array structure.

### Nested Array: EntraRoles.Policies

```json
{
  "PolicyTemplates": {
    "Standard": {
      "ActivationDuration": "PT8H",
      "ApprovalRequired": false,
      "ActivationRequirement": "MultiFactorAuthentication, Justification"
    }
  },
  "EntraRoles": {
    "Policies": [
      {
        "RoleName": "Security Reader",
        "PolicySource": "template",
        "Template": "Standard",
        "ApprovalRequired": true
      },
      {
        "RoleName": "User Administrator",
        "PolicySource": "inline",
        "Policy": {
          "ActivationDuration": "PT4H",
          "ApprovalRequired": false
        }
      }
    ]
  }
}
```

### Top-Level Array: EntraRolePolicies

```json
{
  "PolicyTemplates": {
    "Standard": {
      "ActivationDuration": "PT8H",
      "ApprovalRequired": false
    }
  },
  "EntraRolePolicies": [
    {
      "RoleName": "Security Reader",
      "Template": "Standard"
    },
    {
      "RoleName": "User Administrator",
      "PolicySource": "inline",
      "ActivationDuration": "PT4H",
      "ApprovalRequired": false
    }
  ]
}
```

## Array Entry Structure

Each entry in the array must include:
- **RoleName** (required): The display name of the Entra role

And one of:
- **Template** (recommended): Reference to a template in PolicyTemplates, with optional property overrides
- **Policy** object (inline): Complete policy definition inline
- **PolicySource** = "inline" with flattened policy properties

### Template-Based Entry

```json
{
  "RoleName": "Global Administrator",
  "Template": "Tier0_Critical",
  "ActivationDuration": "PT4H"
}
```

Properties specified directly on the entry override the template values.

### Inline Policy Object

```json
{
  "RoleName": "Helpdesk Administrator",
  "PolicySource": "inline",
  "Policy": {
    "ActivationDuration": "PT2H",
    "ApprovalRequired": true,
    "Approvers": [
      { "Id": "user-guid-1", "Name": "Approver Name" }
    ]
  }
}
```

### Flattened Inline Properties

```json
{
  "RoleName": "Helpdesk Administrator",
  "PolicySource": "inline",
  "ActivationDuration": "PT2H",
  "ApprovalRequired": true,
  "Approvers": [
    { "Id": "user-guid-1", "Name": "Approver Name" }
  ]
}
```

## Legacy Object Format (Still Supported)

The orchestrator still supports the legacy object/dictionary format:

```json
{
  "EntraRoles": {
    "Policies": {
      "Security Reader": {
        "Template": "Standard"
      },
      "User Administrator": {
        "ActivationDuration": "PT4H",
        "ApprovalRequired": false
      }
    }
  }
}
```

## Conflict Detection

The orchestrator will throw an error if both formats are present:
- If both `EntraRolePolicies` (top-level) and `EntraRoles.Policies` exist in the same configuration
- Error message: "Both EntraRolePolicies and EntraRoles.Policies are present. Only one format is allowed."

This ensures clear policy source precedence.

## Differences from Azure Role Policies

Unlike Azure role policies, Entra role policies:
- **Do not require a Scope property** (Entra roles are tenant-level)
- Use role display names directly (no resource path)
- Apply to the entire tenant

## Migration Guide

To migrate from object format to array format:

**Before (Object):**
```json
{
  "EntraRoles": {
    "Policies": {
      "Security Reader": {
        "Template": "Standard"
      }
    }
  }
}
```

**After (Array):**
```json
{
  "EntraRoles": {
    "Policies": [
      {
        "RoleName": "Security Reader",
        "Template": "Standard"
      }
    ]
  }
}
```

## Best Practices

1. **Use templates** for consistent policy application across roles
2. **Use array format** for new configurations to support multiple policy sources
3. **Document PolicySource** explicitly when using inline policies for clarity
4. **Keep backward compatibility** in mind when updating existing configurations
5. **Validate configurations** using `Test-EasyPIMConfigurationValidity` before deployment

## Related Documentation

- [Enhanced Orchestrator Policy Design](Development/Enhanced-Orchestrator-Policy-Design.md)
- [Azure Role Policies Array Format](Azure-Role-Policies-Array.md)
