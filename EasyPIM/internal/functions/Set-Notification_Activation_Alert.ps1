<#
.Synopsis
Admin notification when a role is activated
.Description
notification setting corresponding to rule 15 here https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
.Parameter Notification_Activation_Alert
hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}
.Example
PS> Set-Notification_Activation_Alert -Notification_Activation_Alert @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

set the notification sent to Admins when a role is activated
#>
function Set-Notification_Activation_Alert($Notification_Activation_Alert) {
    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Admin",
        "isDefaultRecipientsEnabled": '+ $Notification_Activation_Alert.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_Activation_Alert.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_Activation_Alert.Recipients | ForEach-Object {
        $rule += '"' + $_ + '",'
    }

    $rule += '
        ],
        "id": "Notification_Admin_EndUser_Assignment",
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
