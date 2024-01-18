function Set-Notification_Activation_Approver ($Notification_Activation_Approver) {
    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Approver",
        "isDefaultRecipientsEnabled": '+ $Notification_Activation_Approver.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_Activation_Approver.notificationLevel + '",
        "notificationRecipients": [
        '
    <# 
            # Cant add backup recipient for this rule

            $Notification_Activation_Approver.Recipients | % {
                $rule += '"' + $_ + '",'
            }
        #>
    $rule += '
        ],
        "id": "Notification_Approver_EndUser_Assignment",
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
