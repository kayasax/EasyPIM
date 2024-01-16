function Set-Notification_Activation_Approvers ($Notification_Activation_Approvers) {
    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Approver",
        "isDefaultRecipientsEnabled": '+ $Notification_Activation_Approvers.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_Activation_Approvers.notificationLevel + '",
        "notificationRecipients": [
        '
    <# 
            # Cant add backup recipient for this rule

            $Notification_Activation_Approvers.Recipients | % {
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
