function Set-Notification_ActiveAssignment_Assignee($Notification_ActiveAssignment_Assignee) {
    $rule = '
                {
                "notificationType": "Email",
                "recipientType": "Requestor",
                "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Assignee.isDefaultRecipientEnabled.ToLower() + ',
                "notificationLevel": "'+ $Notification_ActiveAssignment_Assignee.notificationLevel + '",
                "notificationRecipients": [
                '
    $Notification_ActiveAssignment_Assignee.Recipients | % {
        $rule += '"' + $_ + '",'
    }

    $rule += '
                ],
                "id": "Notification_Requestor_Admin_Assignment",
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
