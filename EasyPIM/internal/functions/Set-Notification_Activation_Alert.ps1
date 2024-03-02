<#
.Synopsis
Admin notification when a role is activated
.Description
notification setting corresponding to rule 15 here https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#notification-rules
.Parameter Notification_Activation_Alert
hashtable for the settings like: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}
.PARAMETER entrarole
set to true if configuration is for an entra role
.Example
PS> Set-Notification_Activation_Alert -Notification_Activation_Alert @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical";"Recipients" = @("email1@domain.com","email2@domain.com")}

set the notification sent to Admins when a role is activated
#>
function Set-Notification_Activation_Alert($Notification_Activation_Alert, [switch]$entrarole) {
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
    $rule = $rule -replace ".$" #remove the last comma
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

    if ($entrarole) {
        $rule='{
            "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule",
            "id": "Notification_Admin_EndUser_Assignment",
            "notificationType": "Email",
            "recipientType": "Admin",
            "isDefaultRecipientsEnabled": '+ $Notification_Activation_Alert.isDefaultRecipientEnabled.ToLower() + ',
            "notificationLevel": "'+ $Notification_Activation_Alert.notificationLevel + '",
            "notificationRecipients": ['
            #write-verbose "recipient : $($Notification_ActiveAssignment_Assignee.Recipients)"
            If ( ($Notification_Activation_Alert.Recipients |Measure-Object |Select-Object -expand count) -gt 0 ){
    
                $Notification_Activation_Alert.Recipients | ForEach-Object {
                $rule += '"' + $_ + '",'
            }
            $rule = $rule -replace ".$" #remove the last comma
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
        }'
    }
    return $rule
}
