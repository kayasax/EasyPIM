﻿<#
.Synopsis
assignee notification when an elligible assignment is created
.Description
correspond to rule 10 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
.Parameter Notification_EligibleAssignment_Assignee
hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}
.PARAMETER EntraRole
set to true if the rule is for an Entra role
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
        $Notification_EligibleAssignment_Assignee,
        [switch]$EntraRole
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

    if($EntraRole){
        $rule = '
        {
            "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule",
            "id": "Notification_Requestor_Admin_Eligibility",
            "notificationType": "Email",
            "recipientType": "Requestor",
            "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Assignee.isDefaultRecipientEnabled.ToLower() + ',
            "notificationLevel": "'+ $Notification_EligibleAssignment_Assignee.notificationLevel + '",
            "notificationRecipients": ['
            If ( ($Notification_EligibleAssignment_Assignee.Recipients |Measure-Object |Select-Object -expand count) -gt 0 ){

            $Notification_EligibleAssignment_Assignee.Recipients | ForEach-Object {
                $rule += '"' + $_ + '",'
            }
            $rule = $rule -replace ".$" #remove the last comma
        }
            $rule += '],
            "target": {
                "caller": "Admin",
                "operations": [
                    "all"
                ],
                "level": "Eligibility",
                "inheritableSettings": [],
                "enforcedSettings": []
            }}'
        }

    return $rule
}
