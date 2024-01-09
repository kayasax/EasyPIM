# EasyPIM V0.3 "PIMper's Paradise"
Powershell function to manage PIM Azure Resource Role settings with simplicity in mind
- Easily manage settings at the subscription level : enter a tenant ID, a subscription ID, a role name 
then the options you want to set for example require justification on activation
- Support multi roles
- Export role settings to csv
- Import role settings from csv

### Sample usage
* Require justification, ticketing and MFA when activating the role "Webmaster"  
 `EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster" -ActivationRequirement "Justification","Ticketing","MultiFactorAuthentication"`
* require Approval and set approvers  
`EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID>-rolename "webmaster" -Approvers  @(@{"Id"="00b34bb3-8a6b-45ce-a7bb-c7f7fb400507";"Name"="John";"Type"="user"}) -ApprovalRequired $true`




