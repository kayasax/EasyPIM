function Set-Notification_EligibleAssignment_Alert($Notification_EligibleAssignment_Alert) {
    write-verbose "Set-Notification_EligibleAssignment_Alert($Notification_EligibleAssignment_Alert)"

    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Admin",
        "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Alert.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Alert.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_EligibleAssignment_Alert.Recipients | % {
        $rule += '"' + $_ + '",'
    }
    $rule = $rule -replace ".$"
    $rule += '
        ],
        "id": "Notification_Admin_Admin_Eligibility",
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
    write-verbose "end function notif elligible alert"
    return $rule
}
