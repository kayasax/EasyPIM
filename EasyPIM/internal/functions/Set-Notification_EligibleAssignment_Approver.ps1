function Set-Notification_EligibleAssignment_Approver($Notification_EligibleAssignment_Approver) {
    #write-verbose "function Set-Notification_EligibleAssignment_Approver"
        
    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Approver",
        "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Approver.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Approver.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_EligibleAssignment_Approver.recipients | ForEach-Object {
        $rule += '"' + $_ + '",'
    }

    $rule += '
        ],
        "id": "Notification_Approver_Admin_Eligibility",
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
        }'
    return $rule
}
