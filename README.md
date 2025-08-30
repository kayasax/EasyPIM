[![PSGallery Version](https://img.shields.io/powershellgallery/v/easypim.svg?style=flat&logo=powershell&label=PSGallery%20Version)](https://www.powershellgallery.com/packages/easypim) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/easypim.svg?style=flat&logo=powershell&label=PSGallery%20Downloads)](https://www.powershellgallery.com/packages/easypim)

[![Orchestrator Version](https://img.shields.io/powershellgallery/v/EasyPIM.Orchestrator.svg?style=flat&logo=powershell&label=Orchestrator%20Version)](https://www.powershellgallery.com/packages/EasyPIM.Orchestrator) [![Orchestrator Downloads](https://img.shields.io/powershellgallery/dt/EasyPIM.Orchestrator.svg?style=flat&logo=powershell&label=Orchestrator%20Downloads)](https://www.powershellgallery.com/packages/EasyPIM.Orchestrator)

## 🚀 Major Release: EasyPIM v2.0 & Orchestrator v1.0

- 🎯 **Major architectural milestone**: Complete module separation
- 🔧 **ARM API compatibility fixes**: Resolves InvalidResourceType errors  
- 🛡️ **Enhanced policy validation**: Proactive error detection with clear guidance
- 📏 **Parameter standardization**: Consistent naming with backward compatibility
- 🏗️ **Production-ready orchestrator**: Feature-complete v1.0.0-beta1

**Beta Installation:**
```pwsh
# Install both modules for complete functionality
Install-Module -Name EasyPIM 
Install-Module -Name EasyPIM.Orchestrator 
```

⚠️ **Breaking Changes in v2.0**: Parameter `assignee` renamed to `principalId` (alias provided for compatibility)

## Introduction

EasyPIM is a PowerShell module created to help you manage Microsoft Privileged Identity Management (PIM) either working with Entra ID, Azure RBAC or groups.
Packed with more than 30 cmdlets, EasyPIM leverages the ARM and Graph APIs complexity to let you configure PIM **Azure Resources**, **Entra Roles** and **groups** settings and assignments in a simple way.

🆕 **Module separation complete**: The JSON-driven orchestrator is now a standalone module: EasyPIM.Orchestrator (requires EasyPIM ≥ 2.0.0).
**Orchestrated flow guide:** [step-by-step](https://github.com/kayasax/EasyPIM/wiki/Invoke%E2%80%90EasyPIMOrchestrator-step%E2%80%90by%E2%80%90step-guide)
🌍 EasyPIM supports multi-cloud (Public, Government, China, Germany) thanks to [Chase Dafnis](https://github.com/CHDAFNI-MSFT)!

## Key features
:boom: Support editing multiple roles at once  
:boom: Copy settings from one role to another  
:boom: Copy eligible assignments from one user to another  
:boom: Export role settings to csv  
:boom: Import role settings from csv  
:boom: Backup all roles  
:boom: New in V1.6 get PIM activity reporting  
:boom: New in V1.7 Approve/Deny pending requests  
:fire: Orchestrated flow (moved to EasyPIM.Orchestrator): [overview](https://github.com/kayasax/EasyPIM/wiki/Invoke%E2%80%90EasyPIMOrchestrator)  
👌 Define your full PIM model (Entra, Azure RBAC, Groups, policies, assignments, protected accounts) from a single JSON.  
👉 Use the dedicated module EasyPIM.Orchestrator and follow the [step-by-step guide](https://github.com/kayasax/EasyPIM/wiki/Invoke%E2%80%90EasyPIMOrchestrator-step%E2%80%90by%E2%80%90step-guide)

🗒️Change log: [https://github.com/kayasax/EasyPIM/wiki/Changelog](https://github.com/kayasax/EasyPIM/wiki/Changelog)

[📸 View the EasyPIM Gallery](Gallery.html)

## Installation

### Stable Release (v1.x)
Core module: [PowerShell Gallery / EasyPIM](https://www.powershellgallery.com/packages/EasyPIM)
```pwsh
Install-Module -Name EasyPIM
```
Updating from an older version:
```pwsh
Update-Module -Name EasyPIM
```

### Beta Release (v2.0) - Recommended for Testing
**🚀 Major architectural improvements with ARM API fixes**
```pwsh
# Install both modules for complete functionality
Install-Module -Name EasyPIM -AllowPrerelease          # v2.0.0-beta1
Install-Module -Name EasyPIM.Orchestrator -AllowPrerelease  # v1.0.0-beta1
```

### Legacy Orchestrator (for v1.x compatibility)
Orchestrator (JSON-driven flow): [PowerShell Gallery / EasyPIM.Orchestrator](https://www.powershellgallery.com/packages/EasyPIM.Orchestrator)
- Requires EasyPIM ≥ 1.10.0 (stable) or ≥ 2.0.0 (beta)
```pwsh
Install-Module -Name EasyPIM.Orchestrator -AllowPrerelease
```

### Getting Started
```pwsh
Import-Module EasyPIM
Import-Module EasyPIM.Orchestrator  # For orchestration features
Get-Command -Module EasyPIM*
```

## Sample usage

*Note: EasyPIM manage PIM Azure Resource settings **at the subscription level by default** : enter a tenant ID, a subscription ID, a role name
then the options you want to set, for example require justification on activation.
If you want to manage the role at another level (Management Group, Resource Group or Resource) please use the `scope` parameter instead of the `subscriptionID`.*


:large_blue_diamond: Get configuration of the Azure Resources roles reader and Webmaster
 ```pwsh
 Get-PIMAzureResourcePolicy -TenantID $tenantID -SubscriptionId $subscriptionID -rolename "reader","webmaster"
 ```

:large_blue_diamond: Require justification, ticketing and MFA when activating the Entra Role testrole
 ```pwsh
 Set-PIMEntraRolePolicy -tenantID $tenantID -rolename "testrole"  -ActivationRequirement "Justification","Ticketing","MultiFactorAuthentication"
 ```

:large_blue_diamond: Require approval and set approvers for Azure roles webmaster and contributor
```pwsh
Set-PIMAzureResourcePolicy -TenantID $tenantID -SubscriptionId $subscriptionID -rolename "webmaster","contributor" -Approvers  @(@{"Id"="00b34bb3-8a6b-45ce-a7bb-c7f7fb400507";"Name"="John";"Type"="user"}) -ApprovalRequired $true
```

:large_blue_diamond: Set maximum activation duration to 4h for the member role of a group
```pwsh
Set-PIMGroupPolicy -tenantID $tenantID -groupID "ba6af9bf-6b28-4799-976e-ff71aed3a1bd" -type member -ActivationDuration "PT4H"
```

:large_blue_diamond: Get a reporting of the PIM activities based on Entra ID Audit logs
```pwsh
$r=Show-PIMReport -tenantID $tenantID
```

:large_blue_diamond: List all eligible assignments for Azure roles
```pwsh
 Get-PIMAzureResourceEligibleAssignment -tenantID $tenantID -subscriptionID $subscriptionId
```

:large_blue_diamond: Create an active assignment for a principal and the Entra role testrole
```pwsh
New-PIMEntraRoleActiveAssignment -tenantID $tenantID -rolename "testrole" -principalID $groupID
```

More samples available in the [documentation](https://github.com/kayasax/EasyPIM/wiki/Documentation)

## Module split and migration
- The following commands moved into the EasyPIM.Orchestrator module:
    - Invoke-EasyPIMOrchestrator
    - Test-PIMPolicyDrift
    - Test-PIMEndpointDiscovery
- After installing EasyPIM.Orchestrator, import it to access these commands. Any legacy shims in the core module will emit guidance and forward where applicable.


## Documentation
[documentation](https://github.com/kayasax/EasyPIM/wiki/Documentation)

## Use cases
Discover how EasyPIM answers to common challenges [Use cases](https://github.com/kayasax/EasyPIM/wiki/Use-Cases)

## Contributors
- **Loïc MICHEL** - Original author and maintainer
- **Chase Dafnis** - Multi-cloud / Azure environment support

## Requirement
* Az.Accounts module
* Permission:
The PIM API for Azure resource roles is developed on top of the Azure Resource Manager framework. You will need to give consent to Azure Resource Management but won’t need any Microsoft Graph API permission. You will also need to make sure the user or the service principal calling the API has at least the Owner or User Access Administrator role on the resource you are trying to administer.
* an administrator must grant consent these permissions to the Microsoft Graph PowerShell application:
"RoleManagementPolicy.ReadWrite.Directory",
                "RoleManagement.ReadWrite.Directory",
                "RoleManagementPolicy.ReadWrite.AzureADGroup",
                "PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup",
                "PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup",
                "PrivilegedAccess.ReadWrite.AzureADGroup"


