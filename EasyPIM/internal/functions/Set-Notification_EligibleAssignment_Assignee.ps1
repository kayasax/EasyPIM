function Set-Notification_EligibleAssignment_Assignee($Notification_EligibleAssignment_Assignee) {
    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Requestor",
        "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Assignee.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Assignee.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_EligibleAssignment_Assignee.Recipients | % {
        $rule += '"' + $_ + '",'
    }
        
    $rule += '
        ],
        "id": "Notification_Requestor_Admin_Eligibility",
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
