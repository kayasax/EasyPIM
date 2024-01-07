# EasyPIM V0.1 "PIMper's Paradise"
Powershell function to manage PIM Azure Resource Role settings with simplicity in mind
- Easily manage settings at the subscription level : enter a tenant ID, a subscription ID, a role name 
then the options you want to set for example require justification on activation
- Support multi roles  

### Sample usage
 `EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster" -ActivationRequirement "Justification","Ticketing","MultiFactorAuthentication"`




