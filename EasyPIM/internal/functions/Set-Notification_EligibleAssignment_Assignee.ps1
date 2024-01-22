<#
.Synopsis
assignee notification when an elligible assignment is created
.Description
correspond to rule 10 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
.Parameter Notification_EligibleAssignment_Assignee
hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

.Example
PS> Set-Notification_EligibleAssignment_Assignee -Notification_EligibleAssignment_Assignee @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

set the notification sent to assignee when elligible assignment is created
.Link

.Notes
#>
function Set-Notification_EligibleAssignment_Assignee {
    [outputType([string])]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        $Notification_EligibleAssignment_Assignee
    )

    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Requestor",
        "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Assignee.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Assignee.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_EligibleAssignment_Assignee.Recipients | ForEach-Object {
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
