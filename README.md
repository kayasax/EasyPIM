# EasyPIM V1.0.2
Powershell module to manage PIM Azure Resource Role settings with simplicity in mind.

Easily manage PIM Azure Resource settings **at the subscription level by default** : enter a tenant ID, a subscription ID, a role name 
then the options you want to set, for example require justification on activation.  
:new: If you want to manage the role at another level (Management Group, Resource Group or Resource) please use the `scope` parameter instead of the `subscriptionID`.

## Key features
:boom: Support editing multiple roles at once  
:boom: Copy settings from another role  
:boom: Export role settings to csv  
:boom: Import role settings from csv  
:boom: Backup all roles  

With the export function you can now edit your PIM settings in Excel then import back your changes :wink:

## Installation
This module is available in the PowerShell gallery: [https://www.powershellgallery.com/packages/EasyPIM/](https://www.powershellgallery.com/packages/EasyPIM/), install it with:
```pwsh
Install-Module -Name EasyPIM -Scope CurrentUser
``` 
![image](https://github.com/kayasax/EasyPIM/assets/1241767/79086c31-19fa-4321-a5ac-6767b8d7ace3)

## Sample usage

:large_blue_diamond: Get configuration of the role "Webmaster"  
 ```pwsh
 Get-PIMAzureResourcePolicy -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster"
 ```

:large_blue_diamond: Require justification, ticketing and MFA when activating the role "Webmaster"  
 ```pwsh
 Set-PIMAzureResourcePolicy -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster" -ActivationRequirement "Justification","Ticketing","MultiFactorAuthentication"
 ```


:large_blue_diamond: Require approval and set approvers for roles webmaster and contributor  
```pwsh
Set-PIMAzureResourcePolicy -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster","contributor" -Approvers  @(@{"Id"="00b34bb3-8a6b-45ce-a7bb-c7f7fb400507";"Name"="John";"Type"="user"}) -ApprovalRequired $true
```


:large_blue_diamond: Set maximum activation duration to 12h  
```pwsh
Set-PIMAzureResourcePolicy -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster" -ActivationDuration "PT12H"
```
More samples in the [documentation](https://github.com/kayasax/EasyPIM/wiki/Documentation)

## Requirement
* Az.Accounts module
* Permission:
The PIM API for Azure resource roles is developed on top of the Azure Resource Manager framework. You will need to give consent to Azure Resource Management but won’t need any Microsoft Graph API permission. You will also need to make sure the user or the service principal calling the API has at least the Owner or User Access Administrator role on the resource you are trying to administer.

## Documentation
[documentation](https://github.com/kayasax/EasyPIM/wiki/Documentation)



