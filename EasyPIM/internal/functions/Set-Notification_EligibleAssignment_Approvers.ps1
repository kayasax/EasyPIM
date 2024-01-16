function Set-Notification_EligibleAssignment_Approvers($Notification_EligibleAssignment_Approvers) {
    #write-verbose "function Set-Notification_EligibleAssignment_Approvers"
        
    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Approver",
        "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Approvers.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Approvers.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_EligibleAssignment_Approvers.recipients | % {
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
