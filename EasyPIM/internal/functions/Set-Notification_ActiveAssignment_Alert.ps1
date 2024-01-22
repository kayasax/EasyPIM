﻿<#
.Synopsis
admin notification when an active assignment is created
.Description
correspond to rule 12 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
.Parameter Notification_ActiveAssignment_Alert
hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

.Example
PS> Set-Notification_ActiveAssignment_Alert -Notification_ActiveAssignment_Alert @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

set the notification sent to admin when active assignment is created
.Link

.Notes
#>
function Set-Notification_ActiveAssignment_Alert($Notification_ActiveAssignment_Alert) {
    $rule = '
    {
    "notificationType": "Email",
    "recipientType": "Admin",
    "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Alert.isDefaultRecipientEnabled.ToLower() + ',
    "notificationLevel": "'+ $Notification_ActiveAssignment_Alert.notificationLevel + '",
    "notificationRecipients": [
    '
    $Notification_ActiveAssignment_Alert.Recipients | ForEach-Object {
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