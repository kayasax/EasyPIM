<#
.Synopsis
approver notification when an active assignment is created
.Description
correspond to rule 14 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
.Parameter Notification_ActiveAssignment_Approver
hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

.Example
PS> Set-Notification_ActiveAssignment_Approver -Notification_ActiveAssignment_Approver @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

set the notification sent to approvers when active assignment is created
.Link

.Notes
#>
function  Set-Notification_ActiveAssignment_Approver($Notification_ActiveAssignment_Approver) {
    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Approver",
        "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Approver.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_ActiveAssignment_Approver.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_ActiveAssignment_Approver.Recipients | ForEach-Object {
        $rule += '"' + $_ + '",'
    }

    $rule += '
        ],
        "id": "Notification_Approver_Admin_Assignment",
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
