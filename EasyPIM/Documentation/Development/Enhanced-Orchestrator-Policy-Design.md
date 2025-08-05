# Enhanced EasyPIM Orchestrator - Policy Management Design

## Overview

This document outlines the design for enhancing the `Invoke-EasyPIMOrchestrator` function to support policy management alongside the existing assignment management capabilities.

## Current State

The current orchestrator supports:
- ✅ Eligible assignments (AzureRoles, EntraIDRoles, GroupRoles)
- ✅ Active assignments (AzureRolesActive, EntraIDRolesActive, GroupRolesActive)
- ✅ Cleanup operations
- ✅ Protected users
- ✅ Delta and Initial modes

## Enhancement Goals

Add policy management capabilities to support:
- 🎯 PIM policy configuration from JSON
- 🎯 Policy templates for reusability
- 🎯 Multiple policy sources (inline, file, template)
- 🎯 Declarative policy management
- 🎯 Integration with existing assignment workflows

## Design Principles

1. **Backward Compatibility**: Existing configurations must continue to work
2. **Flexibility**: Support multiple ways to define policies (inline, files, templates)
3. **Consistency**: Follow existing patterns and naming conventions
4. **Maintainability**: Leverage existing policy functions
5. **Safety**: Provide skip options and validation

## Configuration Schema Enhancement

### New Configuration Sections

#### 1. Policy Definitions
```json
"AzureRolePolicies": [
    {
        "RoleName": "Owner",
        "Scope": "/subscriptions/442734fd-2546-4a3b-b4c7-f351bd5ff93a",
        "PolicySource": "inline|file|template",
        "Policy": { /* inline policy definition */ },
        "PolicyFile": "path/to/policy.csv",
        "PolicyTemplate": "HighSecurity"
    }
],
"EntraRolePolicies": [
    {
        "RoleName": "Security Reader",
        "PolicySource": "inline|file|template",
        "Policy": { /* inline policy definition */ }
    }
],
"GroupPolicies": [
    {
        "GroupId": "group-guid",
        "RoleName": "Owner",
        "PolicySource": "template",
        "PolicyTemplate": "HighSecurity"
    }
]
```

#### 2. Policy Templates
```json
"PolicyTemplates": {
    "HighSecurity": {
        "ActivationDuration": "PT2H",
        "EnablementRules": ["MultiFactorAuthentication", "Justification"],
        "ApprovalRequired": true,
        "AllowPermanentEligibleAssignment": false,
        "MaximumEligibleAssignmentDuration": "P30D"
    },
    "Standard": { /* standard policy settings */ },
    "LowPrivilege": { /* low privilege settings */ }
}
```

### Policy Source Types

1. **Inline**: Policy defined directly in JSON
2. **File**: Reference to CSV file (existing export format)
3. **Template**: Reference to predefined template

## Function Enhancements

### 1. Invoke-EasyPIMOrchestrator Parameters

Add new parameters:
```powershell
[Parameter(Mandatory = $false)]
[switch]$SkipPolicies,

[Parameter(Mandatory = $false)]
[ValidateSet("All", "AzureRoles", "EntraRoles", "GroupRoles")]
[string[]]$PolicyOperations = @("All"),

[Parameter(Mandatory = $false)]
[ValidateSet("initial", "delta", "validate")]
[string]$PolicyMode = "validate"
```

### 2. New Internal Functions

#### Initialize-EasyPIMPolicies
```powershell
function Initialize-EasyPIMPolicies {
    param($Config)
    # Process policy templates
    # Resolve policy sources
    # Validate policy definitions
    # Return processed policy configuration
}
```

#### New-EasyPIMPolicies
```powershell
function New-EasyPIMPolicies {
    param($Config, $TenantId, $SubscriptionId)
    # Apply Azure role policies
    # Apply Entra role policies  
    # Apply Group policies
    # Return results summary
}
```

#### ConvertTo-PolicyCSV
```powershell
function ConvertTo-PolicyCSV {
    param($InlinePolicy, $PolicyType)
    # Convert inline JSON policy to CSV format
    # Use existing Import-PIM*Policy functions
}
```

### 3. Policy Processing Workflow

```
1. Load Configuration
2. Initialize-EasyPIMPolicies
   - Process templates
   - Resolve policy sources
   - Validate policy definitions
3. New-EasyPIMPolicies (if not skipped)
   - Apply Azure role policies
   - Apply Entra role policies
   - Apply Group policies
4. Continue with existing assignment workflow
```

## Policy Modes

### Validate Mode (Default)
- Check policy definitions without applying
- Validate templates and file references
- Report configuration issues

### Delta Mode
- Apply only policies that differ from current state
- Compare with existing policies
- Update only changed policies

### Initial Mode
- Apply all defined policies
- Overwrite existing policies
- Full policy deployment

## Implementation Plan

### Phase 1: Core Infrastructure
1. ✅ Design configuration schema
2. ✅ Create enhanced sample configuration
3. ⏳ Create Initialize-EasyPIMPolicies function
4. ⏳ Add policy parameters to orchestrator
5. ⏳ Create policy processing workflow

### Phase 2: Policy Processing
1. ⏳ Implement ConvertTo-PolicyCSV function
2. ⏳ Create New-EasyPIMPolicies function
3. ⏳ Integrate with existing Import-PIM*Policy functions
4. ⏳ Add policy validation logic

### Phase 3: Integration & Testing
1. ⏳ Integrate policy workflow with orchestrator
2. ⏳ Add comprehensive error handling
3. ⏳ Create unit tests
4. ⏳ Update documentation
5. ⏳ Test backward compatibility

### Phase 4: Advanced Features
1. ⏳ Policy diff reporting
2. ⏳ Policy backup before changes
3. ⏳ Policy rollback capabilities
4. ⏳ Policy validation against Azure limits

## Error Handling

- Validate policy templates exist
- Check file paths for policy files
- Validate policy syntax
- Handle API errors gracefully
- Provide detailed error messages

## Documentation Updates

- Update Invoke-EasyPIMOrchestrator.md
- Add policy configuration examples
- Document policy templates
- Update sample configurations

## Testing Strategy

- Unit tests for new functions
- Integration tests with existing workflows
- Backward compatibility tests
- Policy validation tests
- End-to-end scenarios

## Security Considerations

- Validate policy files are readable
- Sanitize policy inputs
- Respect existing protected users
- Audit policy changes
- Support whatif operations

## Breaking Changes

None expected - enhancement is additive and maintains backward compatibility.

## Future Enhancements

- Policy drift detection
- Policy compliance reporting
- Integration with Azure Policy
- Automated policy recommendations
- Policy version control

---

**Status**: 🚧 Design Complete - Implementation In Progress
**Branch**: feature/orchestrator-policy-management
**Next Steps**: Implement Initialize-EasyPIMPolicies function
