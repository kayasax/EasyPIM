function Set-Notification_ActiveAssignment_Alert($Notification_ActiveAssignment_Alert) {
    $rule = '
    {
    "notificationType": "Email",
    "recipientType": "Admin",
    "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Alert.isDefaultRecipientEnabled.ToLower() + ',
    "notificationLevel": "'+ $Notification_ActiveAssignment_Alert.notificationLevel + '",
    "notificationRecipients": [
    '
    $Notification_ActiveAssignment_Alert.Recipients | % {
        $rule += '"' + $_ + '",'
    }
    
    $rule += '
    ],
    "id": "Notification_Admin_Admin_Assignment",
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
