# EasyPIM Orchestrator

## Table of Contents
- [Overview](#overview)
- [Purpose and Benefits](#purpose-and-benefits)
- [Prerequisites](#prerequisites)
- [Configuration File Structure](#configuration-file-structure)
  - [Configuration Sample](#configuration-sample)
  - [Key Sections Explained](#key-sections-explained)
  - [Duration Format](#duration-format)
  - [Duration and Permanence Options](#duration-and-permanence-options)
  - [Multiple Principals for the Same Assignment](#multiple-principals-for-the-same-assignment)
- [Parameters](#parameters)
- [Running in Different Modes](#running-in-different-modes)
  - [Delta Mode (Default)](#delta-mode-default)
  - [Initial Mode](#initial-mode)
- [Handling of Inherited Assignments](#handling-of-inherited-assignments)
  - [What are Inherited Assignments?](#what-are-inherited-assignments)
  - [How EasyPIM Handles Inherited Assignments](#how-easypim-handles-inherited-assignments)
- [Usage Examples](#usage-examples)
  - [From Local Configuration File](#from-local-configuration-file)
  - [From Azure Key Vault](#from-azure-key-vault)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
  - [Common Issues](#common-issues)
  - [Logging and Diagnostics](#logging-and-diagnostics)
- [Frequently Asked Questions](#frequently-asked-questions)
- [Security Considerations](#security-considerations)
- [Protected Roles and Users](#protected-roles-and-users)
- [Contributing](#contributing)
- [License](#license)

## Overview

The `Invoke-EasyPIMOrchestrator` function is a comprehensive solution for managing Privileged Identity Management (PIM) assignments across Azure, Entra ID (formerly Azure AD), and Groups. It provides a declarative approach to PIM management, allowing you to define desired state in a configuration file and automatically apply it.

## Purpose and Benefits

- **Centralized Management**: Manage all PIM assignments from a single configuration file
- **Automated Deployment**: Apply configurations consistently across environments
- **Declarative Approach**: Define what you want, not how to achieve it
- **Safety Features**: Protects specified users from accidental removal
- **Multiple Deployment Modes**: Choose between delta (safer) or initial (complete) cleanup

## Prerequisites

Before using the orchestrator, ensure you have:

1. **Required PowerShell Modules**:
   - Az.KeyVault
   - Az.Resources
   - EasyPIM

2. **Appropriate Permissions**:
   - Azure: Permissions to manage role assignments
   - Entra ID: Directory role management permissions
   - Groups: Group role assignment permissions

3. **Configuration File**: A valid JSON configuration (local file or in Key Vault)

## Configuration File Structure

The configuration file follows a JSON structure with these key sections (legacy arrays are supported; the unified `Assignments` block is recommended going forward):
- AzureRoles: Eligible assignments for Azure RBAC roles
- AzureRolesActive: Active assignments for Azure RBAC roles
- EntraIDRoles: Eligible assignments for Entra ID directory roles
- EntraIDRolesActive: Active assignments for Entra ID directory roles
- GroupRoles: Eligible assignments for Group roles
- GroupRolesActive: Active assignments for Group roles
- ProtectedUsers: Users that will never be removed in any mode

### Configuration sample:
```json
{
  "AzureRoles": [
    {
      "PrincipalId": "00000000-0000-0000-0000-000000000001",
      "Role": "Reader",
      "Scope": "/subscriptions/12345678-1234-1234-1234-123456789012",
      "Permanent": true
    },
    {
      "PrincipalId": "00000000-0000-0000-0000-000000000002",
      "Role": "Contributor",
      "Scope": "/subscriptions/12345678-1234-1234-1234-123456789012",
      "Duration": "P90D"
    }
  ],
  "AzureRolesActive": [
    {
      "PrincipalId": "00000000-0000-0000-0000-000000000003",
      "Role": "Reader",
      "Scope": "/subscriptions/12345678-1234-1234-1234-123456789012",
      "Duration": "PT8H"
    },
    {
      "PrincipalId": "00000000-0000-0000-0000-000000000004",
      "Role": "Reader",
      "Scope": "/subscriptions/12345678-1234-1234-1234-123456789012",
      "Permanent": true
    }
  ],
  "EntraIDRoles": [
    {
      "PrincipalId": "00000000-0000-0000-0000-000000000005",
      "Rolename": "Global Administrator",
      "Permanent": true
    }
  ],
  "ProtectedUsers": [
    "00000000-0000-0000-0000-000000000099"
  ]
}
```


### Key Sections Explained

| Section | Description |
|---------|-------------|
| **AzureRoles** | Eligible (PIM) assignments for Azure RBAC roles |
| **AzureRolesActive** | Active (immediate) assignments for Azure RBAC roles |
| **EntraIDRoles** | Eligible assignments for Entra ID directory roles. **Note**: Administrative Unit (AU) scoped assignments are detected but cannot be removed automatically due to API limitations |
| **EntraIDRolesActive** | Active assignments for Entra ID directory roles |
| **GroupRoles** | Eligible assignments for Group roles |
| **GroupRolesActive** | Active assignments for Group roles |
| **ProtectedUsers** | Users that will never be removed in any mode |

### Duration Format

Durations follow the ISO 8601 standard:
- `PT8H`: 8 hours
- `P1D`: 1 day
- `P2D`: 2 days
- `P1M`: 1 month
- `P90D`: 90 days

### Duration and Permanence Options

For all assignment types (both eligible and active):

- **Permanent Assignment**: Set `"Permanent": true` for assignments that don't expire
- **Time-bound Assignment**: Set `"Duration": "P90D"` for assignments with specific duration
- **Default Behavior**: If neither is specified, maximum allowed duration by policy will be used
- **Precedence**: If both `Permanent` and `Duration` are specified in the same assignment, the `Permanent` flag takes precedence (the assignment will be permanent and the Duration value will be ignored)

> **Note**: The `Permanent` flag works the same way for both eligible and active assignments. When set to `true`, it creates assignments that don't expire regardless of assignment type.

### Multiple Principals for the Same Assignment

To assign the same role to multiple principals on the same scope with identical settings, you can use the `PrincipalIds` array property instead of `PrincipalId`:

```json
"AzureRoles": [
  {
    "PrincipalIds": [
      "00000000-0000-0000-0000-000000000001",
      "00000000-0000-0000-0000-000000000002",
      "00000000-0000-0000-0000-000000000003"
    ],
    "Rolename": "Reader",
    "Scope": "/subscriptions/12345678-1234-1234-1234-123456789012",
    "Duration": "P90D"
  }
]
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| **KeyVaultName** | String | Yes (KeyVault mode) | | Name of Azure Key Vault containing config |
| **SecretName** | String | Yes (KeyVault mode) | | Name of secret in Key Vault |
| **SubscriptionId** | String | Yes | | Azure subscription ID |
| **ConfigFilePath** | String | Yes (File mode) | | Path to local config file |
| **Mode** | String | No | "delta" | Operating mode ("delta" or "initial") |
| **TenantId** | String | Yes | | Azure tenant ID |
| **Operations** | String[] | No | "All" | Filter operations by role type ("All", "AzureRoles", "EntraRoles", "GroupRoles") |
| **SkipAssignments** | Switch | No | $false | Skip the assignment creation process |
| **SkipCleanup** | Switch | No | $false | Skip the cleanup process (useful for debugging) |

## Running in Different Modes

The orchestrator supports two operating modes:

Note on policies:
- Policies don’t have a separate PolicyMode parameter. When you pass -WhatIf, policies run in validation (no changes). Without -WhatIf, policies apply in delta mode.

### Delta Mode (Default)

In delta mode, the orchestrator:
- Adds any new assignments defined in the configuration
- Only removes assignments that were previously created by the orchestrator and are no longer in the configuration

This is the safer option and suitable for ongoing management.

`Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "11111111-1111-1111-1111-111111111111" -SubscriptionId "22222222-2222-2222-2222-222222222222"`

### Initial Mode

In initial mode, the orchestrator:
- Adds any new assignments defined in the configuration
- Removes ALL assignments not in the configuration (except for protected users)

This is more aggressive and useful for first-time setup or complete resets.

Example command (initial mode)
`Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "11111111-1111-1111-1111-111111111111" -SubscriptionId "22222222-2222-2222-2222-222222222222" -Mode "initial"`

> **⚠️ CAUTION**: Initial mode will prompt for confirmation. It can potentially remove many assignments if your configuration is incomplete.

## Handling of Inherited Assignments

The orchestrator intelligently handles inherited role assignments, particularly in delta cleanup mode:

### What are Inherited Assignments?

Inherited assignments are role assignments that come from a higher scope, such as:
- Assignments made at a Management Group level that apply to subscriptions
- Assignments made at a subscription level that apply to resource groups
- Assignments made at a resource group level that apply to resources

### How EasyPIM Handles Inherited Assignments

1. **Detection**: The orchestrator identifies inherited assignments through various indicators:
   - Assignments with `memberType = "Inherited"`
   - Assignments with `ScopeType = "managementgroup"`
   - Assignments with `ScopeId` containing management group references

2. **Preservation**: Inherited assignments are never removed, even if they're not in your configuration file.

3. **Logging**: When an inherited assignment is detected, it will be logged with a message like:
```
ℹ️ Inherited assignment detected: PrincipalId=00000000-0000-0000-0000-000000000001, Role=Reader, Scope=/subscriptions/12345678-1234-1234-1234-123456789012
```

## Usage Examples

### From Local Configuration File

Delta mode (default):
`Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "11111111-1111-1111-1111-111111111111" -SubscriptionId "22222222-2222-2222-2222-222222222222"`

Initial mode:
`Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "11111111-1111-1111-1111-111111111111" -SubscriptionId "22222222-2222-2222-2222-222222222222" -Mode "initial"`

Preview mode (shows what would happen without making changes):
`Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "11111111-1111-1111-1111-111111111111" -SubscriptionId "22222222-2222-2222-2222-222222222222" -WhatIf`

Skip cleanup:
`Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "11111111-1111-1111-1111-111111111111" -SubscriptionId "22222222-2222-2222-2222-222222222222" -SkipCleanup`

### From Azure Key Vault

Delta mode (default):
`Invoke-EasyPIMOrchestrator -KeyVaultName "MyKeyVault" -SecretName "PIMConfig" -TenantId "11111111-1111-1111-1111-111111111111" -SubscriptionId "22222222-2222-2222-2222-222222222222"`

Initial mode:
`Invoke-EasyPIMOrchestrator -KeyVaultName "MyKeyVault" -SecretName "PIMConfig" -TenantId "11111111-1111-1111-1111-111111111111" -SubscriptionId "22222222-2222-2222-2222-222222222222" -Mode "initial"`

Preview mode:
`Invoke-EasyPIMOrchestrator -KeyVaultName "MyKeyVault" -SecretName "PIMConfig" -TenantId "11111111-1111-1111-1111-111111111111" -SubscriptionId "22222222-2222-2222-2222-222222222222" -WhatIf`

Skip cleanup:
`Invoke-EasyPIMOrchestrator -KeyVaultName "MyKeyVault" -SecretName "PIMConfig" -TenantId "11111111-1111-1111-1111-111111111111" -SubscriptionId "22222222-2222-2222-2222-222222222222" -SkipCleanup`

## Best Practices

1. **Start with Delta Mode**: Always begin with delta mode until you're comfortable with the orchestrator.

2. **Use WhatIf**: Preview changes with `-WhatIf` before applying them, especially in initial mode.

3. **Include Protected Users**: Always populate the `ProtectedUsers` array with critical account IDs such as:
   - Your personal admin account
   - Break-glass accounts
   - Service accounts that manage PIM

4. **Version Control**: Keep your configuration file in source control and track changes.

5. **Proper Scoping**: Be as specific as possible with role scopes to follow least privilege.

6. **Test in Non-Production**: Always test changes in a non-production environment first.

## Troubleshooting

### Common Issues

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| **Assignment creation fails** | Principal doesn't exist | Verify all principal IDs in your config |
| **Cannot find role** | Typo in role name | Ensure exact role names match Azure/Entra ID |
| **Access denied** | Insufficient permissions | Ensure you have required permissions for all operations |
| **Duration format error** | Invalid ISO 8601 format | Ensure durations follow proper format (PT8H, P1D, etc.) |
| **Administrative Unit scoped assignments not removed** | API limitation | AU-scoped Entra role assignments are detected but skipped during cleanup due to API limitations. Remove these manually |

### Logging and Diagnostics

The orchestrator provides detailed logging with different status indicators:

- ✅ Success operations
- ℹ️ Informational messages
- ⚙️ Processing operations
- ⚠️ Warning indicators
- ❌ Error messages
- 🛡️ Username with role 'RoleName' is a protected user, skipping

For additional debugging, use the `-Verbose` parameter:

`Invoke-EasyPIMOrchestrator -ConfigFilePath "C:\Config\pim-config.json" -TenantId "..." -SubscriptionId "..." -Verbose`

## Frequently Asked Questions

### Q: Can I manage cross-tenant PIM assignments?
A: No, each orchestrator run targets a single tenant. You'll need separate runs for multiple tenants.

### Q: How do I find the correct role names and IDs?
A: Use the following commands:
- Azure roles: `Get-AzRoleDefinition`
- Entra ID roles: `Get-MgDirectoryRole`
- Principal IDs: `Get-MgUser` or `Get-MgServicePrincipal`

### Q: Can I schedule the orchestrator to run automatically?
A: Yes, you can create an Azure Automation runbook or a scheduled task to run the orchestrator periodically.

### Q: What happens if my configuration file has an error?
A: The orchestrator will validate the configuration and report any issues before making changes.

### Q: How do I update existing assignments?
A: Modify your configuration file and run the orchestrator again. It will reconcile changes automatically.

### Q: Why aren't my Entra ID role assignments scoped to Administrative Units being removed?
A: Due to current API limitations, the removal of Entra ID role assignments scoped to Administrative Units is not supported in the automatic cleanup process. These assignments will be detected and reported during execution, but you'll need to remove them manually. The orchestrator will output detailed information about these assignments to help you identify them.

## Security Considerations

1. **Protected Users**: Always include critical accounts in the `ProtectedUsers` list.

2. **Key Vault Security**: When using Key Vault, ensure proper access controls.

3. **Credential Management**: Use appropriate authentication when connecting to Azure.

4. **Principle of Least Privilege**: Only grant necessary permissions to the orchestrator identity.

5. **Change Tracking**: Consider implementing audit logging for orchestrator runs.

## Protected Roles and Users

The orchestrator includes built-in safeguards to prevent accidental removal of critical access.

### Protected Users

Users specified in the `ProtectedUsers` array will never have their assignments removed, even in initial mode:

```json
"ProtectedUsers": [
  "7a55ec4d-028e-4ff1-8ee9-93da07b6d5d5", // Break-glass account
  "9f2aacfc-8c80-41a7-ba07-121e0cb29757"  // Administrator account
]
```

---

## Contributing

Contributions to EasyPIM are welcome! Please submit pull requests or open issues on our GitHub repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
`

