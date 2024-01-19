<#
.Synopsis
Approver notification when an elligible assignment is created
.Description
correspond to rule 11 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
.Parameter Notification_EligibleAssignment_Approver
hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

.Example
PS> Set-Notification_EligibleAssignment_Approver -Notification_EligibleAssignment_Approver @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

set the notification sent to approvers  when elligible assignment is created
.Link

.Notes
#>
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
