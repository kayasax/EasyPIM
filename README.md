## Introduction

EasyPIM is a PowerShell module created to help you manage Microsof Entra Privileged Identity Management (PIM).  
Packed with more than 30 cmdlets, EasyPIM leverages the ARM and Graph APIs complexity to let you configure PIM **Azure Resources**, **Entra Roles** and **groups** settings and assignments in a simple way .  
🆕 V1.7 comes with 6 cmdlets to approve or deny Entra and Azure role approvals.


[![PSGallery Version](https://img.shields.io/powershellgallery/v/easypim.svg?style=flat&logo=powershell&label=PSGallery%20Version)](https://www.powershellgallery.com/packages/easypim) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/easypim.svg?style=flat&logo=powershell&label=PSGallery%20Downloads)](https://www.powershellgallery.com/packages/easypim)

🗒️Change log: [https://github.com/kayasax/EasyPIM/wiki/Changelog](https://github.com/kayasax/EasyPIM/wiki/Changelog)

## Key features
:boom: Support editing multiple roles at once  
:boom: Copy settings from one role to another   
:boom: Copy eligible assignments from one user to another   
:boom: Export role settings to csv  
:boom: Import role settings from csv  
:boom: Backup all roles  
:boom: New in V1.6 get PIM activity reporting  
:boom: New in V1.7 Approve/Deny pending requests  
:fire: V1.8.1 Invoke-EasyPIMOrchestrator :fire: [more info](https://github.com/kayasax/EasyPIM/wiki/Invoke%E2%80%90EasyPIMOrchestrator)

With the export function you can now edit your PIM settings in Excel then import back your changes :wink:

## Installation
This module is available on the PowerShell gallery: [https://www.powershellgallery.com/packages/EasyPIM](https://www.powershellgallery.com/packages/EasyPIM), install it with:
```pwsh
Install-Module -Name EasyPIM 
``` 
Updating from an older version:  
```pwsh
Update-Module -Name EasyPIM 
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

## Documentation
[documentation](https://github.com/kayasax/EasyPIM/wiki/Documentation)
