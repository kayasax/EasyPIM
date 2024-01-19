<#
.Synopsis
Assignee notification when a role is activated
.Description
correspond to rule 16 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
.Parameter Notification_Activation_Assignee
hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

.Example
PS> Set-Notification_Activation_Assignee -Notification_Activation_Assignee @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

set the notification sent to assignee when a role is activated
.Link

.Notes
#>
function set-Notification_Activation_Assignee($Notification_Activation_Assignee) {
    $rule = '
         {
         "notificationType": "Email",
         "recipientType": "Requestor",
         "isDefaultRecipientsEnabled": '+ $Notification_Activation_Assignee.isDefaultRecipientEnabled.ToLower() + ',
         "notificationLevel": "'+ $Notification_Activation_Assignee.notificationLevel + '",
         "notificationRecipients": [
         '
    $Notification_Activation_Assignee.Recipients | ForEach-Object {
        $rule += '"' + $_ + '",'
    }
 
    $rule += '
         ],
         "id": "Notification_Requestor_EndUser_Assignment",
         "ruleType": "RoleManagementPolicyNotificationRule",
         "target": {
         "caller": "Admin",
         "operations": [
             "All"
         ],
         "level": "Eligibility",
         "targetObjects": null,
         "inheritableSettings": null,
         "enforcedSettings": null
         }
         }
         '
    return $rule
}
