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
