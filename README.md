# EasyPIM V0.5 "PIMper's Paradise"
Powershell function to manage PIM Azure Resource Role settings with simplicity in mind.

Easily manage settings at the subscription level : enter a tenant ID, a subscription ID, a role name 
then the options you want to set, for example require justification on activation.

With the export function you can edit your PIM settings in Excel then import your changes :wink:

## Key features
:boom: Support editing multiple roles at once  
:boom: Copy settings from another role  
:boom: Export role settings to csv  
:boom: Import role settings from csv  
:boom: Backup all roles  

## Sample usage
:memo: Require justification, ticketing and MFA when activating the role "Webmaster"  
 ```pwsh
 EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster" -ActivationRequirement "Justification","Ticketing","MultiFactorAuthentication"
 ```


:memo: Require approval and set approvers for roles webmaster and contributor  
```pwsh
EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster","contributor" -Approvers  @(@{"Id"="00b34bb3-8a6b-45ce-a7bb-c7f7fb400507";"Name"="John";"Type"="user"}) -ApprovalRequired $true
```


:memo: Set maximum activation duration to 12h  
```pwsh
EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster" -Approvers  @(@{"Id"="00b34bb3-8a6b-45ce-a7bb-c7f7fb400507";"Name"="John";"Type"="user"}) -ActivationDuration "PT12H"
```


:memo: Copy settings from the role Contributor to the roles webmaster and role1  
```pwsh
EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster", "role1" -copyFrom "contributor"
```


:memo: Export role settings to CSV  
```pwsh
EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster","contributor" -export -exportFilename .\EXPORTS\roles.csv
```


:memo: Import role settings from CSV  
```pwsh
EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -import
```


:memo: Backup (export all roles)  
```pwsh
EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -backup
```

## Requirement
* Graph permissions: RoleManagementPolicy.ReadWrite.Directory, RoleManagement.ReadWrite.Directory
* Azure PowerShell: https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell?view=azps-11.1.0

## Configuration
* Enable file logging : set **$logToFile** to **$true**
* You can receive fatal error in a Teams channel: set **$TeamsNotif** to **$true** and configure  your Teams Inbound WebHook URL in **$teamsWebhookURL**

## Parameters

|Parameter|description|
|---|---|
|`$TenantID`| Entra ID TenantID|
|`$SubscriptionId`| Subscription ID|
|`$rolename`| name of roles to update/export ex `-rolename "webmaster","contributor"`|   
|`[Switch] $show `|  show current config only, no change made|
|`[Switch] $export`| export role config to csv|
|`$exportFilename`| save export to this file, if not specified it will create a new file in the EXPORTS folder with curent timestamp|
|`$import `| import settings from this csv file ex `-import c:\temp\myfile.csv`|
|`$$copyFrom`| copy settings from this role name ex `-copyFrom "contributor"`|  
|`[Switch] $backup`| backup all roles to csv |
    
 

    # Maximum activation duration (Duration ref https://en.wikipedia.org/wiki/ISO_8601#Durations)
    * $ActivationDuration

   
    # Activation requirement    
    # accepted values: "None" or one or more options from "Justification", "MultiFactorAuthentication", "Ticketing" ex `-ActivationRequirement "justification","Ticketing"`
    # WARNING: options are CASE SENSITIVE
    * $ActivationRequirement 
     
    # Is approval required to activate a role? ($true|$false)
    * $ApprovalRequired

    # Array of approvers in the format: @(@{"Id"="XXXXXX";"Name"="John":"Type"="user|group"}, .... )
    * $Approvers
    
    # Maximum Eligility Duration
    * $MaximumEligibilityDuration (Duration ref https://en.wikipedia.org/wiki/ISO_8601#Durations)
    
    # Allow permanent eligibility? ($true|$false)
    * $AllowPermanentEligibility

    # Maximum active assignment duration # Duration ref https://en.wikipedia.org/wiki/ISO_8601#Durations
    * $MaximumActiveAssignmentDuration 

    # Allow permanent active assignement? ($true|$false)
    * $AllowPermanentActiveAssignment

    
    # Admin Notification when eligible role is assigned
    # Format:  @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
    * $Notification_EligibleAssignment_Alert
    
    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    # End user notification when eligible role is assigned
    # Format:  @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
    $Notification_EligibleAssignment_Assignee, 
    
    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    # Approver notification when eligible role is assigned
    # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
    $Notification_EligibleAssignment_Approvers, 
    
    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    # Admin Notification when an active role is assigned
    # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
    $Notification_ActiveAssignment_Alert,

    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    # End user Notification when an active role is assigned
    # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
    $Notification_ActiveAssignment_Assignee,

    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    # Approver Notification when an active role is assigned
    # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
    $Notification_ActiveAssignment_Approvers,

    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    # Admin Notification when a is activated
    # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
    $Notification_Activation_Alert,

    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    # End user Notification when a role is activated
    # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
    $Notification_Activation_Assignee,

    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    # Approvers Notification when a role is activated
    # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
    $Notification_Activation_Approvers