<#
.Synopsis
Assignee notification when a role is activated
.Description
correspond to rule 16 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
.Parameter Notification_Activation_Assignee
hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}
.PARAMETER entrarole
set to true if configuration is for an entra role
.Example
PS> Set-Notification_Activation_Assignee -Notification_Activation_Assignee @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

set the notification sent to assignee when a role is activated
.Link

.Notes
#>
function set-Notification_Activation_Assignee($Notification_Activation_Assignee, [switch]$entrarole) {
    $rule = '
         {
         "notificationType": "Email",
         "recipientType": "Requestor",
         "isDefaultRecipientsEnabled": '+ $Notification_Activation_Assignee.isDefaultRecipientEnabled.ToLower() + ',
         "notificationLevel": "'+ $Notification_Activation_Assignee.notificationLevel + '",
         "notificationRecipients": [
         '
    $Notification_Activation_Assignee.Recipients | ForEach-Object {
        $rule += '"' + $_ + '",'
    }
 
    $rule += '
         ],
         "id": "Notification_Requestor_EndUser_Assignment",
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
        $rule = '
        {
            "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule",
            "id": "Notification_Requestor_EndUser_Assignment",
            "notificationType": "Email",
            "recipientType": "Requestor",
            "isDefaultRecipientsEnabled": '+ $Notification_Activation_Assignee.isDefaultRecipientEnabled.ToLower() + ',
         "notificationLevel": "'+ $Notification_Activation_Assignee.notificationLevel + '",
            "notificationRecipients": ['
            #write-verbose "recipient : $($Notification_ActiveAssignment_Assignee.Recipients)"
            If ( ($Notification_Activation_Assignee.Recipients |Measure-Object |Select-Object -expand count) -gt 0 ){
    
                $Notification_Activation_Assignee.Recipients | ForEach-Object {
                $rule += '"' + $_ + '",'
            }
            $rule = $rule -replace ".$"
        }
            $rule += '],
            "target": {
                "caller": "EndUser",
                "operations": [
                    "all"
                ],
                "level": "Assignment",
                "inheritableSettings": [],
                "enforcedSettings": []
            }
        }
        '
    }
    return $rule
}
