﻿<#
.Synopsis
assignee notification when an active assignment is created
.Description
correspond to rule 13 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
.Parameter Notification_ActiveAssignment_Alert
hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}
.PARAMETER entrarole
set to true if configuration is for an entra role

.Example
PS> Set-Notification_ActiveAssignment_Assignee -Notification_ActiveAssignment_Assignee @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

set the notification sent to assignee when active assignment is created
.Link

.Notes
#>function Set-Notification_ActiveAssignment_Assignee($Notification_ActiveAssignment_Assignee, [switch]$entrarole) {
    $rule = '
                {
                "notificationType": "Email",
                "recipientType": "Requestor",
                "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Assignee.isDefaultRecipientEnabled.ToLower() + ',
                "notificationLevel": "'+ $Notification_ActiveAssignment_Assignee.notificationLevel + '",
                "notificationRecipients": [
                '
    $Notification_ActiveAssignment_Assignee.Recipients | ForEach-Object {
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

    if ($entrarole) {
        $rule = '{
        "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule",
        "id": "Notification_Requestor_Admin_Assignment",
        "notificationType": "Email",
        "recipientType": "Requestor",
        "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Assignee.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_ActiveAssignment_Assignee.notificationLevel + '",
        "notificationRecipients": ['
        write-verbose "recipient : $($Notification_ActiveAssignment_Assignee.Recipients)"
        If ( ($Notification_ActiveAssignment_Assignee.Recipients |Measure-Object |Select-Object -expand count) -gt 0 ){

            $Notification_ActiveAssignment_Assignee.Recipients | ForEach-Object {
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
            "level": "Assignment",
            "inheritableSettings": [],
            "enforcedSettings": []
        }
    }'
    }

    return $rule
}
