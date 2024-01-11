# EasyPIM V0.5 "PIMper's Paradise"
Powershell function to manage PIM Azure Resource Role settings with simplicity in mind.
Easily manage settings at the subscription level : enter a tenant ID, a subscription ID, a role name 
then the options you want to set for example require justification on activation
- Support multi roles
- Export role settings to csv
- Import role settings from csv
- Backup all roles

## Sample usage
* Require justification, ticketing and MFA when activating the role "Webmaster"  
 ```EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster" -ActivationRequirement "Justification","Ticketing","MultiFactorAuthentication"```
* Require approval and set approvers for roles webmaster and contributor  
```EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster","contributor" -Approvers  @(@{"Id"="00b34bb3-8a6b-45ce-a7bb-c7f7fb400507";"Name"="John";"Type"="user"}) -ApprovalRequired $true```
* Set maximum activation duration to 12h
```EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster" -Approvers  @(@{"Id"="00b34bb3-8a6b-45ce-a7bb-c7f7fb400507";"Name"="John";"Type"="user"}) -ActivationDuration "PT12H"```
* Copy settings from the role Contributor to the roles webmaster and role1
```EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster", "role1" -copyFrom "contributor"```
* Export role settings to CSV
```EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster","contributor" -export -exportFilename .\EXPORTS\roles.csv```
* Import role settings from CSV
```EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster","contributor" -import```
* Backup (export all roles)
```EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -backup```

## Requirement
* Graph permissions: RoleManagementPolicy.ReadWrite.Directory, RoleManagement.ReadWrite.Directory
* Azure PowerShell: https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell?view=azps-11.1.0

## Configuration
* Enable file logging : set **$logToFile** to **$true**
* You can receive fatal error in a Teams channel: set **$TeamsNotif** to **$true** and configure  your Teams Inbound WebHook URL in **$teamsWebhookURL**

## Parameters