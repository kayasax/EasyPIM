# EasyPIM V0.5 "PIMper's Paradise"
Powershell function to manage PIM Azure Resource Role settings with simplicity in mind.

Easily manage settings at the subscription level : enter a tenant ID, a subscription ID, a role name 
then the options you want to set, for example require justification on activation.

With the export function you can edit your PIM settings in excel then import your changes

## Key features
- Support editing multiple roles at once
- Copy settings from another role
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
```EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -import```

* Backup (export all roles)  
```EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -backup```

## Requirement
* Graph permissions: RoleManagementPolicy.ReadWrite.Directory, RoleManagement.ReadWrite.Directory
* Azure PowerShell: https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell?view=azps-11.1.0

## Configuration
* Enable file logging : set **$logToFile** to **$true**
* You can receive fatal error in a Teams channel: set **$TeamsNotif** to **$true** and configure  your Teams Inbound WebHook URL in **$teamsWebhookURL**

## Parameters

    Entra ID TenantID
    * $TenantID

    # Subscription ID
    * $SubscriptionId

    # name of roles to update/export ex `-rolename "webmaster","contributor"`
    * $rolename

    # show current config only, no change made
    * [Switch] $show 
    
    # export role config to csv
    * [Switch] $export

    # save export to this file, if not specified it will create a new file in the EXPORTS folder with curent timestamp
    * $exportFilename

    # import settings from this csv file ex `-import c:\temp\myfile.csv`
    * $import 

    # copy settings from this role name ex `-copyFrom "contributor"`
    * $copyFrom
    
    # backup all roles to csv 
    * [Switch] $backup

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