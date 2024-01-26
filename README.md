# EasyPIM V1.0.2
Powershell module to manage PIM Azure Resource Role settings with simplicity in mind.

Easily manage PIM Azure Resource settings **at the subscription level by default** : enter a tenant ID, a subscription ID, a role name 
then the options you want to set, for example require justification on activation.  
If you want to manage the role at another level (Management Group, Resource Group or Resource) please use the `scope` parameter instead of the `subscriptionID`.

With the export function you can now edit your PIM settings in Excel then import back your changes :wink:

## Key features
:boom: Support editing multiple roles at once  
:boom: Copy settings from another role  
:boom: Export role settings to csv  
:boom: Import role settings from csv  
:boom: Backup all roles  

![image](https://github.com/kayasax/EasyPIM/assets/1241767/79086c31-19fa-4321-a5ac-6767b8d7ace3)

## Installation
This module is available in the PowerShell gallery: [https://www.powershellgallery.com/packages/EasyPIM/](https://www.powershellgallery.com/packages/EasyPIM/), install it with:
```pwsh
Install-Module -Name EasyPIM -Scope CurrentUser
``` 

## Documentation
[Get-PIMAzureResourcePolicy](https://github.com/kayasax/EasyPIM/wiki/Get%E2%80%90PIMAzureResourcePolicy)

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


:large_blue_diamond: Copy settings from the role Contributor to the roles webmaster and role1  
```pwsh
Copy-PIMAzureResourcePolicy -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster", "role1" -copyFrom "contributor"
```


:large_blue_diamond: Export role settings to CSV  
```pwsh
Export-PIMAzureResourcePolicy -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster","contributor" -export -exportFilename .\EXPORTS\roles.csv
```


:large_blue_diamond: Import role settings from CSV  
```pwsh
Import-PIMAzureResourcePolicy -TenantID <tenantID> -SubscriptionId <subscriptionID> -import "c:\temp\roles.csv"
```


:large_blue_diamond: Backup (export all roles)  
```pwsh
Backup-PIMAzureResourcePolicy -TenantID <tenantID> -SubscriptionId <subscriptionID> 
```

## Requirement
* Az.Accounts module
* Permission:
The PIM API for Azure resource roles is developed on top of the Azure Resource Manager framework. You will need to give consent to Azure Resource Management but won’t need any Microsoft Graph API permission. You will also need to make sure the user or the service principal calling the API has at least the Owner or User Access Administrator role on the resource you are trying to administer.

## Optional configuration (at the bottom of easypim.psm1 file)
* Enable file logging : set **$logToFile** to **$true**
* You can receive fatal error in a Teams channel: set **$TeamsNotif** to **$true** and configure  your Teams Inbound WebHook URL in **$teamsWebhookURL**

## Parameters

|Parameter|description|
|---|---|
|`$TenantID`| Entra ID TenantID|
|`$SubscriptionId`| Subscription ID|
|`$rolename`| name of the roles to update/export ex `-rolename "webmaster","contributor"`|   
|`[Switch] $show`|  show current config only, no change made|
|`[Switch] $export`| export role config to csv|
|`$exportFilename`| save export to this file, if not specified it will create a new file in the EXPORTS folder with curent timestamp|
|`$import`| import settings from this csv file ex `-import c:\temp\myfile.csv`|
|`$copyFrom`| copy settings from this role name ex `-copyFrom "contributor"`|  
|`[Switch] $backup`| backup all roles to csv |
|`$ActivationDuration`| Maximum activation duration (Duration ref https://en.wikipedia.org/wiki/ISO_8601#Durations)|
|`$ActivationRequirement `| Accepted values: "None" or one or more options from "Justification", "MultiFactorAuthentication", "Ticketing" ex `-ActivationRequirement "justification","Ticketing"` WARNING: options are CASE SENSITIVE!|
|`$ApprovalRequired`| Is approval required to activate a role? ($true/$false)|
|`$Approvers`| Array of approvers in the format: @(@{"Id"="XXXXXX";"Name"="John":"Type"="user/group"}, .... )|
|`$MaximumEligibilityDuration`| Maximum Eligility Duration (ref https://en.wikipedia.org/wiki/ISO_8601#Durations)|
|`$AllowPermanentEligibility`| Allow permanent eligibility? ($true/$false)| 
|`$MaximumActiveAssignmentDuration`| Maximum active assignment duration (# Duration )ref https://en.wikipedia.org/wiki/ISO_8601#Durations)|
|`$AllowPermanentActiveAssignment`| Allow permanent active assignement? ($true|$false)|
|`$Notification_EligibleAssignment_Alert`| Admin Notification when eligible role is assigned, rule 9 see Notification Format|   
|`$Notification_EligibleAssignment_Assignee`| End-user notification when eligible role is assigned, rule 10 see Notification Format|  
|`$Notification_EligibleAssignment_Approver`| Approver notification when eligible role is assigned, rule 11 see Notification Format|
|`$Notification_ActiveAssignment_Alert`| Admin Notification when an active role is assigned, rule 12 see Notification Format|
|`$Notification_ActiveAssignment_Assignee`| End user Notification when an active role is assigned, rule 13 see Notification Format|
|`$Notification_ActiveAssignment_Approver`| Approver Notification when an active role is assigned, rule 14see Notification Format|
|`$Notification_Activation_Alert`| Admin Notification when a role is activated, rule 15 see Notification Format|
|`$Notification_Activation_Assignee`| End user Notification when a role is activated, rule 16 see Notification Format|
|`$Notification_Activation_Approver`| Approvers Notification when a role is activated, rule 17 see Notification Format|



### Notification format
All Notifications accept value with the following format:
```pwsh
Set-PIMAzureResourcePolicy -tenantID $tid -subscriptionId $sid -Notification_Activation_Alert @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")} 
```
![image](https://github.com/kayasax/EasyPIM/assets/1241767/5da187a5-a51b-48d0-ba80-dad0fc73bfaf)

