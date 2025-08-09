# EasyPIM Orchestrator Complete Tutorial

## Table of Contents
- [Overview](#overview)
- [Getting Started](#getting-started)
- [Part 1: Understanding the Orchestrator](#part-1-understanding-the-orchestrator)
- [Part 2: Policy Management Tutorial](#part-2-policy-management-tutorial)
- [Part 3: Assignment Management Tutorial](#part-3-assignment-management-tutorial)
- [Part 4: Advanced Configuration Patterns](#part-4-advanced-configuration-patterns)
- [Part 5: Production Deployment Guide](#part-5-production-deployment-guide)
- [Part 6: Troubleshooting and Best Practices](#part-6-troubleshooting-and-best-practices)
- [Part 7: Real-World Scenarios](#part-7-real-world-scenarios)
- [Appendix](#appendix)

## Overview

The EasyPIM Orchestrator is a powerful tool that provides declarative management of Privileged Identity Management (PIM) across three key areas:

- **Azure RBAC Roles**: Subscription, resource group, and resource-level access
- **Entra ID Roles**: Directory and administrative unit-scoped roles
- **Group Roles**: PIM-enabled group memberships

This tutorial will guide you through mastering both assignment management and policy configuration using the orchestrator's comprehensive capabilities.

### What You'll Learn

By the end of this tutorial, you'll be able to:
- Configure comprehensive PIM assignments across all three domains
- Implement advanced policy management with templates and inheritance
- Deploy production-ready configurations with safety mechanisms
- Troubleshoot common issues and optimize your PIM strategy
- Scale your PIM management across multiple environments

### Prerequisites

Before starting this tutorial, ensure you have:

1. **PowerShell 5.1 or later** with the EasyPIM module installed
2. **Administrative permissions** in your Azure tenant and subscriptions
3. **Basic understanding** of PIM concepts and Azure RBAC
4. **Access to Azure Key Vault** (recommended for production)

> **📋 Configuration Schema Reference**: For the complete configuration schema with all available properties, see the [Configuration Schema Reference](#a-complete-configuration-schema-reference) in the Appendix.

---

## Getting Started

### Configuration Methods

The EasyPIM Orchestrator supports two primary configuration methods:

1. **Local File Configuration**: Store configuration in JSON files on your local system or file shares
2. **Azure Key Vault Configuration**: Store configuration securely in Azure Key Vault (recommended for production)

#### Method 1: Local File Configuration

Create a JSON configuration file (e.g., `pim-config.json`):

```json
{
  "PolicyTemplates": {
    "Standard": {
      "ActivationDuration": "PT8H",
  "ActivationRequirement": "MultiFactorAuthentication",
      "ApprovalRequired": false
    }
  },
  "AzureRoles": [
    {
      "PrincipalId": "user-guid",
      "Role": "Reader",
      "Scope": "/subscriptions/subscription-id",
      "Duration": "P30D"
    }
  ],
  "ProtectedUsers": [
    "protected-user-guid"
  ]
}
```

Run with local file:
```powershell
Invoke-EasyPIMOrchestrator `
    -ConfigFilePath "C:\Config\pim-config.json" `
    -TenantId "your-tenant-id" `
    -SubscriptionId "your-subscription-id"
```

#### Method 2: Azure Key Vault Configuration

Store your configuration in Azure Key Vault:
```powershell
# Store configuration in Key Vault
$config = Get-Content "C:\Config\pim-config.json" -Raw
Set-AzKeyVaultSecret -VaultName "MyPIMVault" -Name "PIMConfig" -SecretValue (ConvertTo-SecureString $config -AsPlainText -Force)
```

Run with Key Vault:
```powershell
Invoke-EasyPIMOrchestrator `
    -KeyVaultName "MyPIMVault" `
    -SecretName "PIMConfig" `
    -TenantId "your-tenant-id" `
    -SubscriptionId "your-subscription-id"
```

### JSON Comments Support

EasyPIM includes a JSON preprocessor that strips comments, allowing you to document your configuration:

```json
{
  // Policy templates for different security levels
  "PolicyTemplates": {
    "HighSecurity": {
  "ActivationDuration": "PT2H", // 2 hours max activation
  "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": true
    }
  },
  /* Azure RBAC role assignments */
  "AzureRoles": [
    {
      "PrincipalId": "user-guid", // Replace with actual user GUID
      "Role": "Reader",
      "Scope": "/subscriptions/subscription-id"
    }
  ]
}
```

---

## Part 1: Understanding the Orchestrator

### Core Concepts

The EasyPIM Orchestrator operates on these fundamental principles:

#### 1. Declarative Configuration
Instead of imperative commands, you declare the desired state in JSON format:

```json
{
  "AzureRoles": [
    {
      "PrincipalId": "user-guid",
      "Role": "Reader",
      "Scope": "/subscriptions/subscription-id",
      "Duration": "P30D"
    }
  ]
}
```

#### 2. Two Operation Modes

**Delta Mode (Recommended)**
- Only changes what differs from desired state
- Safe for continuous deployment
- Preserves manually created assignments not in config

**Initial Mode (Use with Caution)**
- Enforces exact state matching
- Removes assignments not in configuration
- Ideal for greenfield deployments

#### 3. Comprehensive Coverage

The orchestrator manages six distinct areas:

| Area | Purpose | Example Use Case |
|------|---------|------------------|
| **AzureRoles** | Eligible Azure RBAC assignments | PIM-enabled subscription access |
| **AzureRolesActive** | Active Azure RBAC assignments | Break-glass immediate access |
| **EntraIDRoles** | Eligible Entra directory roles | PIM-enabled admin roles |
| **EntraIDRolesActive** | Active Entra directory roles | Service account permissions |
| **GroupRoles** | Eligible group memberships | PIM-enabled security groups |
| **GroupRolesActive** | Active group memberships | Immediate group access |

#### 4. Policy Management Integration

Beyond assignments, the orchestrator can now manage PIM policies:

- **Policy Templates**: Reusable policy configurations
- **Multiple Sources**: Inline, file-based, or template policies
- **Comprehensive Coverage**: Azure, Entra, and Group policies

---

## Part 2: Policy Management Tutorial

### Step 1: Understanding Policy Management

Policy management allows you to define PIM policies alongside assignments, providing complete PIM governance in code.

#### Policy Configuration Methods

The orchestrator supports three policy definition methods:

1. **Inline Policies**: Direct JSON policy definition
2. **Template Policies**: Reference to predefined templates
3. **File Policies**: Import from CSV exports

### Step 2: Creating Policy Templates

Define reusable policy templates for consistency:

```json
{
  "PolicyTemplates": {
    "HighSecurity": {
      "ActivationDuration": "PT2H",
  "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": true,
      "Approvers": [
        {
          "id": "security-team-group-id",
          "description": "Security Team",

        }
      ],
  "AllowPermanentEligibility": false,
  "MaximumEligibilityDuration": "P7D"
    },
    "Standard": {
      "ActivationDuration": "PT8H",
  "ActivationRequirement": "MultiFactorAuthentication",
      "ApprovalRequired": false,
  "AllowPermanentEligibility": true,
  "MaximumEligibilityDuration": "P90D"
    },
    "LowPrivilege": {
      "ActivationDuration": "PT4H",
  "ActivationRequirement": "",
      "ApprovalRequired": false,
  "AllowPermanentEligibility": true,
  "MaximumEligibilityDuration": "P365D"
    }
  }
}
```

#### Quick reference: Template vs Inline policy usage

- Use Template when you want to re-use a named configuration across many roles.
- Use Inline when a role needs a one-off policy that differs from templates.

Template example (recommended):

```json
{
  "EntraRoles": {
    "Policies": {
      "Global Administrator": { "Template": "HighSecurity" }
    }
  }
}
```

Inline example:

```json
{
  "AzureRoles": {
    "Policies": {
      "Contributor": {
        "Scope": "/subscriptions/subscription-id",
        "ActivationDuration": "PT4H",
        "ActivationRequirement": "MultiFactorAuthentication",
        "ApprovalRequired": false
      }
    }
  }
}
```

### Step 3: Azure Role Policy Configuration

Configure Azure RBAC policies using the supported nested format:

```json
{
  "AzureRoles": {
    "Policies": {
      "Owner": {
        "Scope": "/subscriptions/subscription-id",
        "Template": "HighSecurity"
      },
      "Contributor": {
        "Scope": "/subscriptions/subscription-id",
        "ActivationDuration": "PT4H",
        "ApprovalRequired": false
      }
    }
  },
  "Assignments": {
    "AzureRoles": [
      {
        "roleName": "Owner",
        "scope": "/subscriptions/subscription-id",
        "assignments": [
          {
            "principalId": "user-guid",
            "principalType": "User",
            "assignmentType": "Eligible",
            "duration": "P30D"
          }
        ]
      }
    ]
  }
}
```

### Step 4: Entra Role Policy Configuration

Configure Entra ID role policies; note that scope is implicit (directory-wide) unless DirectoryScopeId is used in assignments:

```json
{
  "EntraIDRoles": {
    "Policies": {
      "Global Administrator": {
        "Template": "HighSecurity"
      },
      "User Administrator": {
        "ActivationDuration": "PT2H",
        "ActivationRequirement": "MultiFactorAuthentication,Justification",
        "ApprovalRequired": true,
        "Approvers": [
          {
            "id": "admin-group-id",
            "description": "Admin Group",

          }
        ]
      }
    }
  },
  "Assignments": {
    "EntraRoles": [
      {
        "roleName": "Global Administrator",
        "assignments": [
          {
            "principalId": "user-guid",
            "principalType": "User",
            "assignmentType": "Eligible",
            "duration": "P1D"
          }
        ]
      },
      {
        "roleName": "User Administrator",
        "assignments": [
          {
            "principalId": "au-admin-guid",
            "principalType": "User",
            "assignmentType": "Eligible",
            "duration": "P30D",
            "directoryScopeId": "/administrativeUnits/hr-au-guid"
          }
        ]
      }
    ]
  }
}
```

### Step 5: Group Policy Configuration

Configure PIM group policies. Note: Applying group policies is currently limited (validate-only/pending implementation). Include GroupId and RoleName in the policy definition.

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
  },
  "Assignments": {
    "GroupRoles": [
      {
        "groupId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        "roleName": "Member",
        "assignments": [
          {
            "principalId": "user-guid",
            "principalType": "User",
            "assignmentType": "Eligible",
            "duration": "P14D"
          }
        ]
      }
    ]
  }
}
```

### Step 6: File-Based Policy Configuration

Use existing policy exports (deprecated section). File-based policy import is supported via the legacy `AzureRolePolicies` format:

```json
{
  "AzureRolePolicies": [
    {
      "RoleName": "Owner",
      "Scope": "/subscriptions/subscription-id",
      "PolicySource": "file",
      "PolicyFile": "C:\\Policies\\azure-owner-policy.csv"
    }
  ]
}
```

### Step 7: Policy Execution Modes

Control how policies are applied:

```powershell
# Preview policy changes without applying (recommended first step)
Invoke-EasyPIMOrchestrator `
  -ConfigFilePath "C:\Config\pim-config.json" `
  -TenantId "tenant-id" `
  -SubscriptionId "subscription-id" `
  -WhatIf

# Apply changed policies (recommended for production)
Invoke-EasyPIMOrchestrator `
  -ConfigFilePath "C:\Config\pim-config.json" `
  -TenantId "tenant-id" `
  -SubscriptionId "subscription-id"

# Skip policy processing entirely
Invoke-EasyPIMOrchestrator `
  -ConfigFilePath "C:\Config\pim-config.json" `
  -TenantId "tenant-id" `
  -SubscriptionId "subscription-id" `
  -SkipPolicies

# Process only specific policy types
Invoke-EasyPIMOrchestrator `
  -ConfigFilePath "C:\Config\pim-config.json" `
  -TenantId "tenant-id" `
  -SubscriptionId "subscription-id" `
  -PolicyOperations @("AzureRoles", "EntraRoles")
```

Note: For policies, -WhatIf triggers validation (no writes). Without -WhatIf, policies run in delta mode (apply changes). There is no separate -PolicyMode parameter.

---

## Part 3: Assignment Management Tutorial

### Step 1: Basic Assignment Configuration

Let's start with a simple configuration covering all three domains:

```json
{
  "AzureRoles": [
    {
      "PrincipalId": "12345678-1234-1234-1234-123456789012",
      "Role": "Reader",
      "Scope": "/subscriptions/abcdef12-3456-7890-abcd-ef1234567890",
      "Duration": "P30D"
    },
    {
      "PrincipalId": "87654321-4321-4321-4321-210987654321",
      "Role": "Contributor",
      "Scope": "/subscriptions/abcdef12-3456-7890-abcd-ef1234567890/resourceGroups/myResourceGroup",
      "Permanent": true
    }
  ],
  "EntraIDRoles": [
    {
      "PrincipalId": "11111111-2222-3333-4444-555555555555",
      "Rolename": "User Administrator",
      "Duration": "P7D"
    },
    {
      "PrincipalId": "22222222-3333-4444-5555-666666666666",
      "Rolename": "Password Administrator",
      "DirectoryScopeId": "/administrativeUnits/department-au-guid",
      "Duration": "P14D"
    }
  ],
  "GroupRoles": [
    {
      "PrincipalId": "66666666-7777-8888-9999-000000000000",
      "GroupId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      "RoleName": "Member",
      "Duration": "P14D"
    },
    {
      "PrincipalId": "77777777-8888-9999-aaaa-bbbbbbbbbbbb",
      "GroupId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      "RoleName": "Owner",
      "Duration": "P7D"
    }
  ],
  "ProtectedUsers": [
    "99999999-8888-7777-6666-555555555555"
  ]
}
```

### Step 2: Understanding Assignment Properties

#### Required Properties by Type

**Azure Roles:**
- `PrincipalId`: User, service principal, or group GUID
- `Role`: Azure RBAC role name (e.g., "Owner", "Contributor", "Reader")
- `Scope`: Azure resource scope (management group, subscription, resource group, or resource)

**Azure Role Scope Examples:**
```json
{
  "AzureRoles": [
    {
      "PrincipalId": "user-guid",
      "Role": "Reader",
      "Scope": "/providers/Microsoft.Management/managementGroups/mg-root"
    },
    {
      "PrincipalId": "group-guid",
      "Role": "Contributor",
      "Scope": "/subscriptions/subscription-id"
    },
    {
      "PrincipalId": "service-principal-guid",
      "Role": "Owner",
      "Scope": "/subscriptions/subscription-id/resourceGroups/rg-name"
    },
    {
      "PrincipalId": "user-guid",
      "Role": "Storage Blob Data Reader",
      "Scope": "/subscriptions/sub-id/resourceGroups/rg-name/providers/Microsoft.Storage/storageAccounts/storage-name"
    }
  ]
}
```

**Entra ID Roles:**
- `PrincipalId`: User, group or service principal GUID
- `Rolename`: Entra directory role name (e.g., "Global Administrator", "User Administrator")
- `DirectoryScopeId`: (Optional) Administrative Unit scope ID for AU-scoped assignments

**Entra ID Role Scope Examples:**
```json
{
  "EntraIDRoles": [
    {
      "PrincipalId": "user-guid",
      "Rolename": "User Administrator",
      "Duration": "P7D"
    },
    {
      "PrincipalId": "admin-guid",
      "Rolename": "Password Administrator",
      "DirectoryScopeId": "/administrativeUnits/au-guid",
      "Duration": "P30D"
    },
    {
      "PrincipalId": "helpdesk-user-guid",
      "Rolename": "Helpdesk Administrator",
      "DirectoryScopeId": "/administrativeUnits/department-au-guid",
      "Duration": "P14D"
    }
  ]
}
```

**Group Roles:**
- `PrincipalId`: User GUID
- `GroupId`: PIM-enabled group GUID
- `RoleName`: Group role ("Owner" or "Member")

> **Note**: For Group roles, you must specify the role within the group. Use "Owner" for group ownership privileges or "Member" for standard group membership.

#### Duration and Permanence Options

All assignment types support these options:

```json
{
  "Duration": "P30D",     // Time-bound assignment (ISO 8601 format)
  "Permanent": true       // Never expires (takes precedence over Duration)
}
```

If neither is specified, the maximum policy-allowed duration is used.

#### Common ISO 8601 Duration Examples

```
PT8H    = 8 hours
P1D     = 1 day
P7D     = 1 week
P30D    = 30 days
P90D    = 90 days
P365D   = 1 year
```

### Step 3: Multi-Principal Assignments

Assign the same role to multiple users efficiently:

```json
{
  "AzureRoles": [
    {
      "PrincipalIds": [
        "user1-guid",
        "user2-guid",
        "user3-guid"
      ],
      "Role": "Reader",
      "Scope": "/subscriptions/subscription-id",
      "Duration": "P30D"
    }
  ]
}
```

### Step 3.2: Understanding Azure RBAC Scope Hierarchy

Azure RBAC assignments can be made at different scope levels, with inheritance flowing from higher to lower levels:

**Scope Hierarchy (Top to Bottom):**
1. **Management Group** - Applies to all subscriptions and resources within the management group
2. **Subscription** - Applies to all resource groups and resources within the subscription
3. **Resource Group** - Applies to all resources within the resource group
4. **Resource** - Applies only to the specific resource

**Management Group Example:**
```json
{
  "AzureRoles": [
    {
      "Role": "Security Reader",
      "Scope": "/providers/Microsoft.Management/managementGroups/company-root",
      "Duration": "P90D"
    }
  ]
}
```

**Principal Type Considerations:**
- **Groups**: Security-enabled Azure AD groups (useful for managing multiple users)
- **Service Principals**: Applications, managed identities, or automated services

> **Best Practice**: Use groups for Azure RBAC assignments to simplify management and reduce the number of individual assignments.

### Step 3.3: Group Role Assignments

Group roles require specifying whether you want "Owner" or "Member" privileges within the PIM-enabled group:

```json
{
  "GroupRoles": [
    {
      "PrincipalId": "user1-guid",
      "GroupId": "security-group-guid",
      "RoleName": "Member",
      "Duration": "P30D"
    },
    {
      "PrincipalId": "admin-user-guid",
      "GroupId": "security-group-guid",
      "RoleName": "Owner",
      "Duration": "P7D"
    }
  ]
}
```

**Group Role Types:**
- **Member**: Standard group membership with member privileges
- **Owner**: Group ownership with ability to manage group settings and membership

### Step 3.4: Administrative Unit (AU) Scoped Entra Roles

Entra ID roles can be assigned at the Administrative Unit scope, providing more granular control over role assignments:

```json
{
  "EntraIDRoles": [
    {
      "PrincipalId": "hr-admin-guid",
      "Rolename": "User Administrator",
      "DirectoryScopeId": "/administrativeUnits/hr-department-au-guid",
      "Duration": "P30D"
    },
    {
      "PrincipalId": "it-helpdesk-guid",
      "Rolename": "Password Administrator",
      "DirectoryScopeId": "/administrativeUnits/it-department-au-guid",
      "Duration": "P14D"
    }
  ]
}
```

**Administrative Unit Benefits:**
- **Departmental Administration**: Delegate admin rights only within specific organizational units
- **Least Privilege**: Limit role scope to only the users/resources that need management
- **Compliance**: Meet regulatory requirements for segregation of duties

> **Note**: Not all Entra ID roles support AU scope. Roles like Global Administrator are tenant-wide only. Check the [Microsoft documentation](https://docs.microsoft.com/en-us/azure/active-directory/roles/administrative-units) for AU-compatible roles.

### Step 4: Running Your First Assignment

Create your configuration file (`pim-config.json`) and run:

```powershell
# Preview changes without applying
Invoke-EasyPIMOrchestrator `
    -ConfigFilePath "C:\Config\pim-config.json" `
    -TenantId "your-tenant-id" `
    -SubscriptionId "your-subscription-id" `
    -WhatIf

# Basic execution (delta mode)
Invoke-EasyPIMOrchestrator `
    -ConfigFilePath "C:\Config\pim-config.json" `
    -TenantId "your-tenant-id" `
    -SubscriptionId "your-subscription-id"

# Process only specific operation types
Invoke-EasyPIMOrchestrator `
    -ConfigFilePath "C:\Config\pim-config.json" `
    -TenantId "your-tenant-id" `
    -SubscriptionId "your-subscription-id" `
    -Operations @("AzureRoles", "EntraRoles")
```

### Step 5: Understanding the Output

The orchestrator provides detailed feedback:

```
✅ Azure Role: user@domain.com assigned Reader on /subscriptions/...
ℹ️  Entra Role: user@domain.com already has User Administrator
⚙️  Processing Group assignment for group-guid
⚠️  WARNING: Initial mode will remove unmanaged assignments
🛡️  Protected user detected, skipping removal
```

---

## Part 4: Advanced Configuration Patterns

### Pattern 1: Multi-Environment Configuration

Structure your configuration for different environments with consistent policy application:

```json
{
  "PolicyTemplates": {
    "Production": {
      "ActivationDuration": "PT2H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": true,
      "AllowPermanentEligibility": false,
      "MaximumEligibilityDuration": "P7D",
      "Approvers": [
        {
          "id": "production-approvers-group-guid",
          "description": "Production Approvers"
        }
      ]
    },
    "Development": {
      "ActivationDuration": "PT8H",
      "ActivationRequirement": "MultiFactorAuthentication",
      "ApprovalRequired": false,
      "AllowPermanentEligibility": true,
      "MaximumEligibilityDuration": "P90D"
    }
  },
  "EntraRoles": {
    "Policies": {
      "Global Administrator": { "Template": "Production" },
      "User Administrator": { "Template": "Development" }
    }
  },
  "AzureRoles": {
    "Policies": {
      "Owner": {
        "Scope": "/subscriptions/prod-subscription-id",
        "Template": "Production"
      },
      "Contributor": {
        "Scope": "/subscriptions/dev-subscription-id",
        "Template": "Development"
      }
    }
  },
  "Assignments": {
    "EntraRoles": [
      {
        "roleName": "Global Administrator",
        "assignments": [
          {
            "principalId": "user-guid",
            "principalType": "User",
            "assignmentType": "Eligible",
            "duration": "P1D"
          }
        ]
      },
      {
        "roleName": "User Administrator",
        "assignments": [
          {
            "principalId": "au-admin-guid",
            "principalType": "User",
            "assignmentType": "Eligible",
            "duration": "P30D",
            "directoryScopeId": "/administrativeUnits/hr-au-guid"
          }
        ]
      }
    ],
    "AzureRoles": [
      {
        "roleName": "Owner",
        "scope": "/subscriptions/prod-subscription-id",
        "assignments": [
          {
            "principalId": "prod-admin-guid",
            "principalType": "User",
            "assignmentType": "Eligible",
            "duration": "P7D",
            "justification": "Production subscription management"
          }
        ]
      },
      {
        "roleName": "Contributor",
        "scope": "/subscriptions/dev-subscription-id",
        "assignments": [
          {
            "principalId": "dev-team-guid",
            "principalType": "Group",
            "assignmentType": "Eligible",
            "duration": "P90D",
            "justification": "Development team access"
          }
        ]
      }
    ]
  }
}
```

### Pattern 2: Role-Based Assignment Grouping

Organize assignments by role for easier management:

```json
{
  "AzureRoles": [
    {
      "PrincipalIds": ["admin1-guid", "admin2-guid"],
      "Role": "Owner",
      "Scope": "/subscriptions/subscription-id",
      "Duration": "P30D"
    }
  ],
  "EntraIDRoles": [
    {
      "PrincipalIds": ["global-admin1-guid", "global-admin2-guid"],
      "Rolename": "Global Administrator",
      "Duration": "P1D"
    }
  ]
}
```

### Pattern 3: Conditional Access Integration

Configure policies with Conditional Access requirements using Authentication Context:

```json
{
  "PolicyTemplates": {
    "ConditionalAccessRequired": {
      "ActivationDuration": "PT1H",
      "ActivationRequirement": "MultiFactorAuthentication",
      "ApprovalRequired": false,
      "AuthenticationContext_Enabled": true,
      "AuthenticationContext_Value": "c1",
      "AllowPermanentEligibility": false,
      "MaximumEligibilityDuration": "P7D"
    }
  },
  "EntraRoles": {
    "Policies": {
      "Global Administrator": {
        "Template": "ConditionalAccessRequired"
      },
      "Security Administrator": {
        "Template": "ConditionalAccessRequired"
      }
    }
  },
  "AzureRoles": {
    "Policies": {
      "Owner": {
        "Scope": "/subscriptions/critical-subscription-id",
        "Template": "ConditionalAccessRequired"
      }
    }
  },
  "Assignments": {
    "EntraRoles": [
      {
        "roleName": "Global Administrator",
        "assignments": [
          {
            "principalId": "admin-user-guid",
            "principalType": "User",
            "assignmentType": "Eligible",
            "duration": "P7D",
            "justification": "Administrative access with Conditional Access"
          }
        ]
      }
    ],
    "AzureRoles": [
      {
        "roleName": "Owner",
        "scope": "/subscriptions/critical-subscription-id",
        "assignments": [
          {
            "principalId": "admin-user-guid",
            "principalType": "User",
            "assignmentType": "Eligible",
            "duration": "P7D",
            "justification": "Critical subscription access"
          }
        ]
      }
    ]
  }
}
```

**Authentication Context Integration:**

The `AuthenticationContext_Value` property integrates with Azure AD Conditional Access policies:

1. **Set up Conditional Access Authentication Context** in Azure AD:
   - Navigate to Azure AD > Security > Conditional Access > Authentication context
   - Create context values (e.g., "c1" for high-security operations)
   - Configure policies that trigger additional security requirements

2. **Configure PIM Policy** with the authentication context:
   - When users activate roles with this policy, they must satisfy the Conditional Access policy
   - This can require specific devices, locations, or additional MFA methods
   - Provides granular control over privileged access conditions

3. **Example Use Cases**:
   - Require access from corporate-managed devices for admin roles
   - Enforce location-based restrictions for sensitive operations
   - Mandate additional MFA methods for critical role activations

### Pattern 4: Protected Users and Break-Glass Account Management

Safely manage emergency access accounts and protected users:

```json
{
  "AzureRolesActive": [
    {
      "PrincipalId": "breakglass1-guid",
      "Role": "Owner",
      "Scope": "/subscriptions/subscription-id",
      "Permanent": true
    }
  ],
  "EntraIDRolesActive": [
    {
      "PrincipalId": "breakglass1-guid",
      "Rolename": "Global Administrator",
      "Permanent": true
    }
  ],
  "ProtectedUsers": [
    "breakglass1-guid",
    "breakglass2-guid",
    "service-account-guid"
  ]
}
```

**Understanding Protected Users:**

The `ProtectedUsers` array is a critical safety mechanism that prevents the orchestrator from removing assignments for specific users:

1. **Purpose**: Prevents accidental removal of critical assignments
2. **Use Cases**:
   - Break-glass emergency accounts
   - Service accounts with permanent assignments
   - VIP users who require special handling
   - Accounts managed outside of the orchestrator

3. **Behavior**:
   - In delta mode: Protected users' assignments are never removed
   - In initial mode: Orchestrator will warn about protected users but not remove their assignments
   - Assignments can still be added or modified for protected users

4. **Best Practices**:
   - Always include break-glass accounts in ProtectedUsers
   - Document why each user is protected
   - Regularly review the protected users list
   - Use service account GUIDs, not user accounts that might change

---

## Part 5: Production Deployment Guide

### Step 1: Configuration Validation Framework

Implement a validation pipeline using EasyPIM's built-in capabilities:

```powershell
# EasyPIM includes built-in JSON preprocessing and validation
function Test-PIMConfiguration {
    param($ConfigPath, $TenantId, $SubscriptionId)

    # Use WhatIf to validate configuration without making changes
    try {
        Invoke-EasyPIMOrchestrator `
            -ConfigFilePath $ConfigPath `
            -TenantId $TenantId `
            -SubscriptionId $SubscriptionId `
            -WhatIf `
            -Verbose

        Write-Host "✅ Configuration validation passed" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Configuration validation failed: $($_.Exception.Message)"
        throw
    }
}

# Run validation
Test-PIMConfiguration `
    -ConfigPath "C:\Config\pim-config.json" `
    -TenantId "your-tenant-id" `
    -SubscriptionId "your-subscription-id"
```

**Benefits of Built-in Validation:**
- JSON syntax validation with comment support
- Schema validation for all configuration properties
- Principal existence validation
- Role and scope availability checks
- Policy template reference validation

### Step 2: Azure Key Vault Integration

Store configurations securely:

```powershell
# Store configuration in Key Vault
$config = Get-Content "C:\Config\pim-config.json" -Raw
Set-AzKeyVaultSecret -VaultName "MyPIMVault" -Name "PIMConfig" -SecretValue (ConvertTo-SecureString $config -AsPlainText -Force)

# Deploy from Key Vault
Invoke-EasyPIMOrchestrator `
    -KeyVaultName "MyPIMVault" `
    -SecretName "PIMConfig" `
    -TenantId "tenant-id" `
    -SubscriptionId "subscription-id"
```

### Step 3: CI/CD Pipeline Integration

Example Azure DevOps pipeline structure (adapt based on your specific needs):

```yaml
# Note: This is a conceptual example - test thoroughly before production use
trigger:
  branches:
    include:
    - main
  paths:
    include:
    - config/pim-config.json

variables:
  - group: PIM-Variables

stages:
- stage: Validate
  jobs:
  - job: ValidateConfig
    steps:
    - task: PowerShell@2
      displayName: 'Validate PIM Configuration'
      inputs:
        targetType: 'inline'
        script: |
          # Install EasyPIM module
          Install-Module EasyPIM -Force -Scope CurrentUser

          # Validate using WhatIf
          Invoke-EasyPIMOrchestrator `
            -ConfigFilePath "$(System.DefaultWorkingDirectory)/config/pim-config.json" `
            -TenantId "$(TenantId)" `
            -SubscriptionId "$(SubscriptionId)" `
            -WhatIf

- stage: Deploy
  dependsOn: Validate
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: DeployPIM
    environment: 'PIM-Production'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: PowerShell@2
            displayName: 'Deploy PIM Configuration'
            inputs:
              targetType: 'inline'
              script: |
                Install-Module EasyPIM -Force -Scope CurrentUser

                Invoke-EasyPIMOrchestrator `
                  -KeyVaultName "$(KeyVaultName)" `
                  -SecretName "PIMConfig" `
                  -TenantId "$(TenantId)" `
                  -SubscriptionId "$(SubscriptionId)"
```

> **⚠️ Important**: This pipeline example is conceptual. Test thoroughly in a non-production environment and adapt authentication methods, variable handling, and approval processes to your organization's requirements.

### Step 4: Monitoring and Alerting

Implement monitoring for PIM changes:

```powershell
# Example monitoring script
function Monitor-PIMChanges {
    param($TenantId, $SubscriptionId)

    # Get recent PIM assignments
    $recentAssignments = Get-PIMAzureResourceEligibleAssignment -tenantID $TenantId -subscriptionId $SubscriptionId |
        Where-Object { $_.AssignmentState -eq "Eligible" -and $_.CreatedDateTime -gt (Get-Date).AddHours(-24) }

    if ($recentAssignments.Count -gt 0) {
        $message = "⚠️ New PIM assignments detected in the last 24 hours: $($recentAssignments.Count)"

        # Send to monitoring system (Teams, email, etc.)
        Send-TeamsNotification -Message $message -Webhook $env:TeamsWebhook
    }
}
```

---

## Part 6: Troubleshooting and Best Practices

### Common Issues and Solutions

#### Issue 1: Assignment Creation Fails

**Symptoms:**
```
❌ Failed to create assignment: Principal not found
```

**Solutions:**
1. Verify principal GUID format
2. Ensure principal exists in tenant
3. Check principal type (User vs ServicePrincipal)

```powershell
# Validate principal existence
Get-MgUser -UserId "principal-guid"
# or
Get-MgServicePrincipal -ServicePrincipalId "principal-guid"
```

#### Issue 2: Role Name Not Found

**Symptoms:**
```
❌ Role 'CustomRole' not found in scope
```

**Solutions:**
1. Use exact role names from Azure portal
2. Check role availability at the specified scope
3. For custom roles, ensure they're defined at the correct scope

```powershell
# List available roles
Get-AzRoleDefinition | Where-Object { $_.IsCustom -eq $false } | Select-Object Name
```

#### Issue 3: Policy Application Failures

**Symptoms:**
```
❌ Failed to apply policy: Invalid policy configuration
```

**Solutions:**
1. Validate policy template references
2. Check file paths for policy files
3. Ensure policy properties are correctly formatted

```powershell
# Test policy file import
$csvData = Import-Csv "C:\Policies\policy.csv"
$csvData | Get-Member
```

#### Issue 4: AU-Scoped Assignment Issues

**Symptoms:**
```
❌ Administrative Unit scoped assignment cannot be automatically removed
```

**Solutions:**
1. AU-scoped Entra role assignments are detected but cannot be removed automatically due to API limitations
2. These assignments must be removed manually through the Azure portal or PowerShell
3. The orchestrator will report these assignments but skip cleanup

```powershell
# Manually remove AU-scoped assignment
Remove-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -UnifiedRoleEligibilityScheduleRequestId "request-id"
```

### Best Practices Checklist

#### ✅ Configuration Management
- [ ] Store configurations in version control
- [ ] Use meaningful commit messages
- [ ] Implement pull request reviews
- [ ] Test in non-production first

#### ✅ Security
- [ ] Always populate `ProtectedUsers` array
- [ ] Use Azure Key Vault for production configs
- [ ] Implement proper access controls
- [ ] Regular access reviews

#### ✅ Monitoring
- [ ] Log all orchestrator executions
- [ ] Monitor for unauthorized changes
- [ ] Set up alerting for policy violations
- [ ] Track assignment usage patterns

#### ✅ Documentation
- [ ] Document all role assignments
- [ ] Maintain policy rationale
- [ ] Keep emergency procedures updated
- [ ] Train team members

---

## Part 7: Real-World Scenarios

### Scenario 1: Multi-Subscription Enterprise

**Challenge:** Manage PIM across multiple subscriptions with different security requirements.

**Solution:**
```json
{
  "PolicyTemplates": {
    "Production": {
      "ActivationDuration": "PT2H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": true,
      "AllowPermanentEligibility": false,
      "MaximumEligibilityDuration": "P7D",
      "Approvers": [
        {
          "id": "production-security-team-guid",
          "description": "Production Security Team"
        }
      ]
    },
    "Development": {
      "ActivationDuration": "PT8H",
      "ActivationRequirement": "MultiFactorAuthentication",
      "ApprovalRequired": false,
      "AllowPermanentEligibility": true
    }
  },
  "AzureRoles": {
    "Policies": {
      "Owner": {
        "Scope": "/subscriptions/prod-sub1-id",
        "Template": "Production"
      },
      "Contributor": {
        "Scope": "/subscriptions/dev-sub1-id",
        "Template": "Development"
      }
    }
  },
  "Assignments": {
    "AzureRoles": [
      {
        "roleName": "Owner",
        "scope": "/subscriptions/prod-sub1-id",
        "assignments": [
          {
            "principalId": "prod-team-guid",
            "principalType": "Group",
            "assignmentType": "Eligible",
            "duration": "P7D",
            "justification": "Production environment management"
          }
        ]
      },
      {
        "roleName": "Contributor",
        "scope": "/subscriptions/dev-sub1-id",
        "assignments": [
          {
            "principalId": "dev-team-guid",
            "principalType": "Group",
            "assignmentType": "Eligible",
            "duration": "P90D",
            "justification": "Development environment access"
          }
        ]
      }
    ]
  }
}
```

### Scenario 2: Regulatory Compliance (SOX, GDPR)

**Challenge:** Implement strict controls for financial systems access.

**Solution:**
```json
{
  "PolicyTemplates": {
    "FinancialCompliance": {
      "ActivationDuration": "PT1H",
  "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": true,
      "Approvers": [
        {
          "id": "financial-approval-group-guid",
          "description": "Financial Approval Group",

        }
      ],
  "AllowPermanentEligibility": false,
  "MaximumEligibilityDuration": "P7D"
    }
  },
  "AzureRoles": [
    {
      "PrincipalIds": ["finance-team-guids"],
      "Role": "Owner",
      "Scope": "/subscriptions/financial-systems-subscription",
      "Duration": "P1D"
    }
  ]
}
```

### Scenario 3: Time-Limited Project Access

**Challenge:** Provide temporary elevated access for project work with manual cleanup.

**Solution:**
```json
{
  "AzureRoles": [
    {
      "PrincipalIds": ["project-team-guids"],
      "Role": "Contributor",
      "Scope": "/subscriptions/project-subscription",
      "Duration": "P30D"
    }
  ],
  "ProtectedUsers": [],
  "// Note": "Manually remove assignments when project completes"
}
```

### Scenario 4: Zero Trust Implementation

**Challenge:** Implement just-in-time access with conditional access integration.

**Solution:**
```json
{
  "PolicyTemplates": {
    "ZeroTrustAccess": {
      "ActivationDuration": "PT30M",
  "ActivationRequirement": "MultiFactorAuthentication",
      "ApprovalRequired": false,
      "AuthenticationContext_Value": "c1",
  "AllowPermanentEligibility": false,
  "MaximumEligibilityDuration": "P1D"
    }
  },
  "AzureRoles": [
    {
      "PrincipalIds": ["admin-team-guids"],
      "Role": "Owner",
      "Scope": "/subscriptions/critical-subscription",
      "Duration": "P1D"
    }
  ]
}
```

---

## Appendix

### A. Complete Configuration Schema Reference

Based on the actual EasyPIM implementation:

```json
{
  "PolicyTemplates": {
    "TemplateName": {
      "ActivationDuration": "PT2H",
      "ActivationRequirement": "MultiFactorAuthentication,Justification",
      "ApprovalRequired": false,
      "AllowPermanentEligibility": false,
      "MaximumEligibilityDuration": "P30D",
      "AllowPermanentActiveAssignment": false,
      "MaximumActiveAssignmentDuration": "PT8H",
      "Approvers": [
        {
          "id": "12345678-1234-1234-1234-123456789012",
          "description": "Security Team"
        }
      ],
      "AuthenticationContext_Enabled": true,
      "AuthenticationContext_Value": "c1",
      "Notification_EligibleAssignment_Alert": {
        "isDefaultRecipientEnabled": "true",
        "notificationLevel": "All",
        "Recipients": ["admin@company.com"]
      },
      "Notification_EligibleAssignment_Assignee": {
        "isDefaultRecipientEnabled": "true",
        "notificationLevel": "All",
        "Recipients": ["user@company.com"]
      },
      "Notification_EligibleAssignment_Approver": {
        "isDefaultRecipientEnabled": "false",
        "notificationLevel": "Critical",
        "Recipients": ["approver@company.com"]
      },
      "Notification_ActiveAssignment_Alert": {
        "isDefaultRecipientEnabled": "true",
        "notificationLevel": "All",
        "Recipients": ["admin@company.com"]
      },
      "Notification_ActiveAssignment_Assignee": {
        "isDefaultRecipientEnabled": "true",
        "notificationLevel": "All",
        "Recipients": ["user@company.com"]
      },
      "Notification_ActiveAssignment_Approver": {
        "isDefaultRecipientEnabled": "false",
        "notificationLevel": "Critical",
        "Recipients": ["approver@company.com"]
      },
      "Notification_Activation_Alert": {
        "isDefaultRecipientEnabled": "true",
        "notificationLevel": "All",
        "Recipients": ["admin@company.com"]
      },
      "Notification_Activation_Assignee": {
        "isDefaultRecipientEnabled": "true",
        "notificationLevel": "All",
        "Recipients": ["user@company.com"]
      },
      "Notification_Activation_Approver": {
        "isDefaultRecipientEnabled": "false",
        "notificationLevel": "Critical",
        "Recipients": ["approver@company.com"]
      }
    }
  },
  "EntraRoles": {
    "Policies": {
      "Global Administrator": {
        "Template": "TemplateName"
      },
      "User Administrator": {
        "ActivationDuration": "PT2H",
        "ActivationRequirement": "MultiFactorAuthentication,Justification",
        "ApprovalRequired": true,
        "AllowPermanentEligibility": false,
        "MaximumEligibilityDuration": "P7D",
        "Approvers": [
          {
            "id": "admin-group-id",
            "description": "Admin Group"
          }
        ],
        "AuthenticationContext_Enabled": true,
        "AuthenticationContext_Value": "c1",
        "Notification_EligibleAssignment_Alert": {
          "isDefaultRecipientEnabled": "true",
          "notificationLevel": "All",
          "Recipients": ["admin@company.com"]
        },
        "Notification_Activation_Alert": {
          "isDefaultRecipientEnabled": "true",
          "notificationLevel": "Critical",
          "Recipients": ["security@company.com"]
        }
      }
    }
  },
  "AzureRoles": {
    "Policies": {
      "Owner": {
        "Scope": "/subscriptions/subscription-id",
        "Template": "TemplateName"
      },
      "Contributor": {
        "Scope": "/subscriptions/subscription-id",
        "ActivationDuration": "PT4H",
        "ActivationRequirement": "MultiFactorAuthentication",
        "ApprovalRequired": false,
        "AllowPermanentEligibility": true,
        "MaximumEligibilityDuration": "P90D"
      }
    }
  },
  "Groups": {
    "Policies": {
      "group-guid": {
        "RoleName": "Member",
        "Template": "TemplateName"
      }
    }
  },
  "Assignments": {
    "EntraRoles": [
      {
        "roleName": "Global Administrator",
        "assignments": [
          {
            "principalId": "12345678-1234-1234-1234-123456789012",
            "principalType": "User",
            "assignmentType": "Eligible",
            "justification": "Administrative duties"
          },
          {
            "principalId": "87654321-4321-4321-4321-210987654321",
            "principalType": "User",
            "assignmentType": "Active",
            "duration": "PT8H",
            "justification": "Emergency access"
          }
        ]
      }
    ],
    "AzureRoles": [
      {
        "roleName": "Owner",
        "scope": "/subscriptions/subscription-id",
        "assignments": [
          {
            "principalId": "12345678-1234-1234-1234-123456789012",
            "principalType": "User",
            "assignmentType": "Eligible",
            "justification": "Subscription management"
          }
        ]
      }
    ],
    "Groups": [
      {
        "groupId": "group-guid",
        "roleName": "Member",
        "assignments": [
          {
            "principalId": "12345678-1234-1234-1234-123456789012",
            "principalType": "User",
            "assignmentType": "Eligible",
            "justification": "Project team access"
          }
        ]
      }
    ]
  }
}
```

**Key Properties Supported:**

**Policy Templates & Policies:**
- `ActivationDuration`: ISO 8601 duration (e.g., "PT2H", "PT8H")
- `ActivationRequirement`: Comma-separated requirements ("MultiFactorAuthentication", "Justification")
- `ApprovalRequired`: Boolean for approval workflow
- `AllowPermanentEligibility`: Boolean for permanent eligible assignments
- `MaximumEligibilityDuration`: Maximum duration for eligible assignments
- `AllowPermanentActiveAssignment`: Boolean for permanent active assignments
- `MaximumActiveAssignmentDuration`: Maximum duration for active assignments
- `Approvers`: Array of approver objects with id and description
- `AuthenticationContext_Enabled`: Boolean to enable authentication context
- `AuthenticationContext_Value`: Authentication context value (e.g., "c1")
- `Notification_EligibleAssignment_Alert`: Notification configuration object

**Assignments:**
- `principalId`: Azure AD Object ID (GUID format)
- `principalType`: "User", "Group", or "ServicePrincipal"
- `assignmentType`: "Eligible" or "Active"
- `duration`: Required for Active assignments (ISO 8601 format)
- `justification`: Optional reason for assignment

### B. PowerShell Command Reference

#### Basic Commands
```powershell
# Local file configuration
Invoke-EasyPIMOrchestrator -ConfigFilePath "path" -TenantId "id" -SubscriptionId "id"

# Key Vault configuration
Invoke-EasyPIMOrchestrator -KeyVaultName "vault" -SecretName "secret" -TenantId "id" -SubscriptionId "id"

# Preview mode
Invoke-EasyPIMOrchestrator -ConfigFilePath "path" -TenantId "id" -SubscriptionId "id" -WhatIf

# Initial mode (destructive)
Invoke-EasyPIMOrchestrator -ConfigFilePath "path" -TenantId "id" -SubscriptionId "id" -Mode "initial"
```

#### Policy-Specific Commands
```powershell
# Skip policies
Invoke-EasyPIMOrchestrator -ConfigFilePath "path" -TenantId "id" -SubscriptionId "id" -SkipPolicies

# Preview policy changes without applying
Invoke-EasyPIMOrchestrator -ConfigFilePath "path" -TenantId "id" -SubscriptionId "id" -WhatIf

# Apply policy changes (delta mode is default when not using -WhatIf)
Invoke-EasyPIMOrchestrator -ConfigFilePath "path" -TenantId "id" -SubscriptionId "id"

# Specific policy operations
Invoke-EasyPIMOrchestrator -ConfigFilePath "path" -TenantId "id" -SubscriptionId "id" -PolicyOperations @("AzureRoles")
```

#### Filtering Options
```powershell
# Specific operations
-Operations @("AzureRoles", "EntraRoles", "GroupRoles")

# Skip assignment processing
-SkipAssignments

# Skip cleanup (assignments only)
-SkipCleanup

# Verbose output
-Verbose
```

### C. Useful PowerShell Snippets

#### Find Principal GUIDs
```powershell
# Get user GUID
(Get-MgUser -Filter "userPrincipalName eq 'user@domain.com'").Id

# Get group GUID (for Azure RBAC assignments)
(Get-MgGroup -Filter "displayName eq 'GroupName'").Id

# Get service principal GUID
(Get-MgServicePrincipal -Filter "displayName eq 'AppName'").Id

# List all groups (useful for finding security groups for Azure RBAC)
Get-MgGroup | Where-Object { $_.SecurityEnabled -eq $true } | Select-Object DisplayName, Id

# Get Administrative Unit GUID (for AU-scoped Entra role assignments)
(Get-MgDirectoryAdministrativeUnit -Filter "displayName eq 'HR Department'").Id

# List all Administrative Units
Get-MgDirectoryAdministrativeUnit | Select-Object DisplayName, Id
```

#### Export Current Policies
```powershell
# Export Azure role policies
Export-PIMAzureResourcePolicy -tenantID $tenantId -subscriptionId $subscriptionId

# Export Entra role policies
Export-PIMEntraRolePolicy -tenantID $tenantId

# Export group policies
Export-PIMGroupPolicy -tenantID $tenantId
```

---

This completes your comprehensive tutorial for mastering the EasyPIM Orchestrator. The tutorial covers both policy management and assignment management with accurate, real-world examples and production-ready patterns.
